# Bulk Student Upload - Excel Template Guide

## Excel Format Required

Create an Excel file (.xlsx or .xls) with **8 columns** in this exact order:

| Column # | Column Name | Description | Example |
|----------|-------------|-------------|---------|
| 1 | Name | Student's full name | John Smith |
| 2 | Roll Number | Unique student roll number | 2024001 |
| 3 | Class | Student's class/grade | 10A |
| 4 | Password | Student's date of birth (will be used as password) | 15/08/2010 |
| 5 | Bus Number | Assigned bus number (must exist in system) | BUS-101 |
| 6 | Route Name | Assigned route name (must match bus route) | East Route |
| 7 | Stopping | Student's pickup/drop stop (must exist in route) | Main Street Stop |
| 8 | Email | Student's email address | 2024001@schoolname.com |

## Auto-Populated Fields

The following fields will be automatically set for all uploaded students:

- **Parent Contact**: Optional (left blank, can be updated later)
- **Notification Type**: "Voice Notification"
- **Language Preference**: "English"
- **Notification Preference**: "Time"
- **Notification Time**: 10 minutes before arrival

## Important Notes

### Email Format
- Must be valid email format
- Must be unique across all students
- Typically use: `rollnumber@schoolname.com`

### Bus Number, Route Name, and Stopping
- Bus Number must exist in the system's bus database
- Route Name must match the route assigned to that bus
- Stopping must be one of the stops defined in that route
- System will validate all these before import

### Validation
- All fields are required (except Parent Contact which is auto-populated as optional)
- The system will check for:
  - Duplicate email addresses (both in database and within the upload file)
  - Duplicate roll numbers (both in database and within the upload file)
  - Valid bus numbers
  - Matching route names
  - Valid stop names
- Invalid rows will be highlighted in red with error messages
- Only valid rows will be imported

## Sample Excel Data

Here's a sample of what your Excel should look like:

| Name | Roll Number | Class | Password | Bus Number | Route Name | Stopping | Email |
|------|-------------|-------|----------|------------|------------|----------|-------|
| John Smith | 2024001 | 10A | 15/08/2010 | BUS-101 | East Route | Main Street Stop | 2024001@abc.com |
| Jane Doe | 2024002 | 10A | 22/03/2010 | BUS-101 | East Route | Park Avenue Stop | 2024002@abc.com |
| Mike Johnson | 2024003 | 9B | 10/11/2011 | BUS-102 | West Route | School Gate | 2024003@abc.com |

## Usage Instructions

1. Prepare your Excel file with student data following the format above
2. Navigate to Student Management screen
3. Click the "Bulk Upload" button in the top right
4. Select your Excel file
5. Wait for validation to complete
6. Review the parsed data in the table
   - Valid students will have a green checkmark
   - Invalid students will have a red error icon with details
7. Click "Import Valid Students" to create accounts
8. Wait for the import to complete
9. Review the results summary

## Tips

- Start with a small batch (5-10 students) to test the process
- Make sure all buses and routes are created in the system first
- Use a consistent email format for easy management
- Keep a backup of your Excel file
- Double-check bus numbers and route names match exactly (case-sensitive)

## Troubleshooting

**Error: "Bus number not found"**
- Verify the bus exists in Bus Management
- Check spelling and case (e.g., "BUS-101" vs "bus-101")

**Error: "Route name does not match bus route"**
- Go to Bus Management and check which route is assigned to that bus
- Make sure the Route Name column matches exactly

**Error: "Stopping not found in route"**
- Go to Route Management and check the stops for that route
- Make sure the Stopping column matches one of the stop names exactly

**Error: "Email already exists"**
- Check if a student with that email is already registered
- Make sure there are no duplicate emails in your Excel file

**Error: "Roll number already exists"**
- Check if a student with that roll number is already registered
- Make sure there are no duplicate roll numbers in your Excel file
