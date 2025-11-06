const functions = require('firebase-functions/v2');
const admin = require('firebase-admin');

// Initialize Firebase Admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Cost-optimized data archiving function
 * Archives old data to reduce storage costs
 */
exports.archiveOldData = functions.scheduler.onSchedule('0 2 * * 0', async (event) => {
  try {
    console.log('Starting data archiving process...');
    
    const cutoffDate = new Date();
    cutoffDate.setMonth(cutoffDate.getMonth() - 3); // Archive data older than 3 months
    
    const batch = db.batch();
    let archivedCount = 0;
    
    // Archive old notifications
    const oldNotifications = await db.collection('notifications')
      .where('sentAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
      .limit(500) // Process in batches
      .get();
    
    for (const doc of oldNotifications.docs) {
      // Move to archive collection
      const archiveRef = db.collection('archived_notifications').doc(doc.id);
      batch.set(archiveRef, {
        ...doc.data(),
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Delete from main collection
      batch.delete(doc.ref);
      archivedCount++;
    }
    
    // Archive old bus location history
    const oldBusHistory = await db.collection('bus_location_history')
      .where('timestamp', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
      .limit(500)
      .get();
    
    for (const doc of oldBusHistory.docs) {
      const archiveRef = db.collection('archived_bus_locations').doc(doc.id);
      batch.set(archiveRef, {
        ...doc.data(),
        archivedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      batch.delete(doc.ref);
      archivedCount++;
    }
    
    // Commit the batch
    if (archivedCount > 0) {
      await batch.commit();
      console.log(`✅ Archived ${archivedCount} old records`);
      
      // Log archiving stats
      await db.collection('system_stats').doc('archiving').set({
        lastRun: admin.firestore.FieldValue.serverTimestamp(),
        recordsArchived: archivedCount,
        totalRuns: admin.firestore.FieldValue.increment(1),
      }, { merge: true });
    } else {
      console.log('No old records to archive');
    }
    
  } catch (error) {
    console.error('Error in data archiving:', error);
    // Log error for monitoring
    await db.collection('system_errors').add({
      function: 'archiveOldData',
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * Monitor and log Firebase usage statistics
 * Helps track costs and optimize performance
 */
exports.collectUsageStats = functions.scheduler.onSchedule('0 */6 * * *', async (event) => {
  try {
    console.log('Collecting usage statistics...');
    
    const stats = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      collections: {},
      functions: {
        invocationCount: 0,
        errorCount: 0,
      }
    };
    
    // Collect collection statistics
    const collections = ['students', 'schools', 'bus_status', 'notifications', 'payments', 'adminusers'];
    
    for (const collectionName of collections) {
      try {
        const snapshot = await db.collection(collectionName).count().get();
        stats.collections[collectionName] = {
          documentCount: snapshot.data().count,
          estimatedReadCost: snapshot.data().count * 0.000036, // $0.000036 per read
        };
      } catch (error) {
        console.error(`Error counting ${collectionName}:`, error);
        stats.collections[collectionName] = { error: error.message };
      }
    }
    
    // Get function execution stats from last 24 hours
    try {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      
      const functionLogs = await db.collection('function_executions')
        .where('timestamp', '>', admin.firestore.Timestamp.fromDate(yesterday))
        .get();
      
      stats.functions.invocationCount = functionLogs.size;
      stats.functions.errorCount = functionLogs.docs.filter(doc => 
        doc.data().status === 'error'
      ).length;
      
    } catch (error) {
      console.error('Error collecting function stats:', error);
    }
    
    // Calculate estimated monthly costs
    const totalReads = Object.values(stats.collections)
      .reduce((sum, col) => sum + (col.estimatedReadCost || 0), 0);
    
    stats.estimatedMonthlyCosts = {
      firestoreReads: totalReads * 30, // Monthly estimate
      functions: stats.functions.invocationCount * 0.0000004 * 30, // $0.0000004 per invocation
      total: (totalReads * 30) + (stats.functions.invocationCount * 0.0000004 * 30)
    };
    
    // Store statistics
    await db.collection('usage_statistics').add(stats);
    
    console.log('✅ Usage statistics collected:', {
      totalDocuments: Object.values(stats.collections).reduce((sum, col) => 
        sum + (col.documentCount || 0), 0),
      estimatedMonthlyCost: stats.estimatedMonthlyCosts.total.toFixed(4)
    });
    
  } catch (error) {
    console.error('Error collecting usage stats:', error);
    await db.collection('system_errors').add({
      function: 'collectUsageStats',
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * Optimize database queries by cleaning up unused indexes
 * and suggesting new ones based on usage patterns
 */
exports.optimizeDatabase = functions.scheduler.onSchedule('0 3 * * 1', async (event) => {
  try {
    console.log('Starting database optimization...');
    
    // Analyze query patterns from the last month
    const oneMonthAgo = new Date();
    oneMonthAgo.setMonth(oneMonthAgo.getMonth() - 1);
    
    const queryLogs = await db.collection('query_logs')
      .where('timestamp', '>', admin.firestore.Timestamp.fromDate(oneMonthAgo))
      .get();
    
    const queryPatterns = {};
    
    queryLogs.docs.forEach(doc => {
      const data = doc.data();
      const pattern = `${data.collection}_${data.fields?.join('_') || 'all'}`;
      
      if (!queryPatterns[pattern]) {
        queryPatterns[pattern] = {
          count: 0,
          avgExecutionTime: 0,
          collection: data.collection,
          fields: data.fields || [],
        };
      }
      
      queryPatterns[pattern].count++;
      queryPatterns[pattern].avgExecutionTime = 
        (queryPatterns[pattern].avgExecutionTime + (data.executionTime || 0)) / 2;
    });
    
    // Identify slow queries that need indexing
    const slowQueries = Object.entries(queryPatterns)
      .filter(([pattern, data]) => data.avgExecutionTime > 100) // > 100ms
      .sort((a, b) => b[1].count - a[1].count) // Sort by frequency
      .slice(0, 10); // Top 10
    
    const optimizationReport = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      totalQueries: queryLogs.size,
      slowQueries: slowQueries.map(([pattern, data]) => ({
        pattern,
        frequency: data.count,
        avgExecutionTime: data.avgExecutionTime,
        collection: data.collection,
        suggestedIndex: data.fields.length > 1 ? data.fields : null,
      })),
      recommendations: [],
    };
    
    // Generate recommendations
    slowQueries.forEach(([pattern, data]) => {
      if (data.fields.length > 1) {
        optimizationReport.recommendations.push({
          type: 'INDEX',
          message: `Consider adding composite index for ${data.collection} on fields: ${data.fields.join(', ')}`,
          priority: data.count > 100 ? 'HIGH' : 'MEDIUM',
        });
      }
    });
    
    await db.collection('optimization_reports').add(optimizationReport);
    
    console.log('✅ Database optimization completed:', {
      totalQueries: queryLogs.size,
      slowQueries: slowQueries.length,
      recommendations: optimizationReport.recommendations.length,
    });
    
  } catch (error) {
    console.error('Error in database optimization:', error);
    await db.collection('system_errors').add({
      function: 'optimizeDatabase',
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * Clean up expired cache entries and temporary data
 */
exports.cleanupExpiredData = functions.scheduler.onSchedule('0 1 * * *', async (event) => {
  try {
    console.log('Starting expired data cleanup...');
    
    const now = new Date();
    let cleanedCount = 0;
    
    // Clean up expired verification codes
    const expiredCodes = await db.collection('verification_codes')
      .where('expiresAt', '<', admin.firestore.Timestamp.fromDate(now))
      .limit(100)
      .get();
    
    const batch = db.batch();
    
    expiredCodes.docs.forEach(doc => {
      batch.delete(doc.ref);
      cleanedCount++;
    });
    
    // Clean up old temporary files references
    const oldTempFiles = await db.collection('temp_files')
      .where('createdAt', '<', admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() - 24 * 60 * 60 * 1000) // 24 hours ago
      ))
      .limit(100)
      .get();
    
    oldTempFiles.docs.forEach(doc => {
      batch.delete(doc.ref);
      cleanedCount++;
    });
    
    // Clean up old error logs (keep only last 30 days)
    const oldErrors = await db.collection('system_errors')
      .where('timestamp', '<', admin.firestore.Timestamp.fromDate(
        new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000) // 30 days ago
      ))
      .limit(100)
      .get();
    
    oldErrors.docs.forEach(doc => {
      batch.delete(doc.ref);
      cleanedCount++;
    });
    
    if (cleanedCount > 0) {
      await batch.commit();
      console.log(`✅ Cleaned up ${cleanedCount} expired records`);
    }
    
    // Log cleanup stats
    await db.collection('system_stats').doc('cleanup').set({
      lastRun: admin.firestore.FieldValue.serverTimestamp(),
      recordsCleaned: cleanedCount,
      totalRuns: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
    
  } catch (error) {
    console.error('Error in cleanup:', error);
    await db.collection('system_errors').add({
      function: 'cleanupExpiredData',
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});

/**
 * Generate cost optimization reports
 */
exports.generateCostReport = functions.scheduler.onSchedule('0 9 1 * *', async (event) => {
  try {
    console.log('Generating monthly cost optimization report...');
    
    const now = new Date();
    const lastMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    // Get usage statistics for the month
    const usageStats = await db.collection('usage_statistics')
      .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(lastMonth))
      .where('timestamp', '<', admin.firestore.Timestamp.fromDate(thisMonth))
      .get();
    
    if (usageStats.empty) {
      console.log('No usage statistics found for report generation');
      return;
    }
    
    // Calculate averages and trends
    const stats = usageStats.docs.map(doc => doc.data());
    const avgDailyReads = stats.reduce((sum, stat) => 
      sum + Object.values(stat.collections || {}).reduce((colSum, col) => 
        colSum + (col.documentCount || 0), 0), 0) / stats.length;
    
    const avgDailyCost = stats.reduce((sum, stat) => 
      sum + (stat.estimatedMonthlyCosts?.total || 0), 0) / stats.length;
    
    const report = {
      month: lastMonth.toISOString().substring(0, 7), // YYYY-MM format
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metrics: {
        avgDailyReads,
        avgDailyCost,
        projectedMonthlyCost: avgDailyCost * 30,
      },
      optimizations: {
        cachingImpact: avgDailyCost * 0.4, // Estimated 40% reduction from caching
        indexingImpact: avgDailyCost * 0.15, // Estimated 15% reduction from indexing
        archivingImpact: avgDailyCost * 0.1, // Estimated 10% reduction from archiving
      },
      recommendations: [
        'Implement more aggressive caching for frequently accessed data',
        'Archive data older than 6 months to reduce storage costs',
        'Optimize cloud function execution frequency',
        'Consider using Firestore bundles for static data',
      ],
      status: 'completed',
    };
    
    await db.collection('cost_reports').add(report);
    
    console.log('✅ Cost optimization report generated:', {
      projectedMonthlyCost: report.metrics.projectedMonthlyCost.toFixed(2),
      potentialSavings: (report.optimizations.cachingImpact + 
        report.optimizations.indexingImpact + 
        report.optimizations.archivingImpact).toFixed(2),
    });
    
  } catch (error) {
    console.error('Error generating cost report:', error);
    await db.collection('system_errors').add({
      function: 'generateCostReport',
      error: error.message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});