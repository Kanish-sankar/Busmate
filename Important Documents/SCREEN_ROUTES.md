# BusMate — UI Screen Routes Reference

Last updated: 2025-10-24

This document lists all named routes (GetX GetPage routes) used by the web and mobile apps, plus frequently referenced screens that are navigated using Get.to()/Get.toNamed() (class-based navigation). For each route we include: route constant, path, primary widget, and the file where that page is registered or invoked.

## How this was built
- Scanned project for GetPage and Get.to/Get.toNamed usages.
- Read `busmate_web/lib/modules/Routes/app_pages.dart` and `busmate_app/lib/meta/nav/pages.dart` to capture registered routes.
- Listed additional screens discovered via code search where Get.to(...) is used.

---

## Web — Named Routes (GetPages)
Registered in: `busmate_web/lib/modules/Routes/app_pages.dart`

- Routes.SPLASH
  - Path: `/splash`
  - Widget: `SplashScreen`
  - File: `busmate_web/lib/modules/splash/splash_screen.dart`
  - Notes: Initial route for the web app (`AppPages.INITIAL`)

- Routes.LOGIN
  - Path: `/login`
  - Widget: `LoginScreen`
  - File: `busmate_web/lib/modules/Authentication/login_screen.dart`
  - Notes: Admin/web login screen; contains links to reset-password and register routes

- Routes.RESET_PASSWORD
  - Path: `/reset-password`
  - Widget: `ResetPasswordScreen`
  - File: `busmate_web/lib/modules/Authentication/reset_password.dart`

- Routes.REGISTER
  - Path: `/register`
  - Widget: `RegisterScreen`
  - File: `busmate_web/lib/modules/Authentication/register_screen.dart`

- Routes.SUPER_ADMIN_DASHBOARD
  - Path: `/super-admin-dashboard`
  - Widget: `SuperAdminDashboard`
  - File: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart`
  - Notes: Protected by `AuthMiddleware(requiredRole: UserRole.superAdmin)`

- Routes.SCHOOL_ADMIN_DASHBOARD
  - Path: `/school-admin-dashboard`
  - Widget: `SchoolAdminDashboard`
  - File: `busmate_web/lib/modules/SchoolAdmin/dashboard/dashboard_screen.dart`
  - Notes: Protected by `AuthMiddleware(requiredRole: UserRole.schoolAdmin)`

---

## Mobile (Flutter app) — Named Routes (GetPages)
Registered in: `busmate_app/lib/meta/nav/pages.dart` (part: `routes.dart`)
Used as `initialRoute: Routes.splash` in `busmate_app/lib/busmate.dart`

- Routes.splash
  - Path: `/splash`
  - Widget: `SplashScreen`
  - File: `busmate_app/lib/presentation/parents_module/splash/screen/splash_screen.dart`

- Routes.sigIn
  - Path: `/signIn`
  - Widget: `SignInScreen`
  - File: `busmate_app/lib/presentation/parents_module/sigin/screen/sigin_screen.dart`

- Routes.stopLocation
  - Path: `/stopLocation`
  - Widget: `StopLocation`
  - File: `busmate_app/lib/presentation/parents_module/stoplocation/screen/stop_location_screen.dart`

- Routes.forgotPassword
  - Path: `/forgotPassword`
  - Widget: `ForgotPass`
  - File: `busmate_app/lib/presentation/parents_module/forgotpass/screen/forgot_pass.dart`

- Routes.stopNotify
  - Path: `/stopNotify`
  - Widget: `StopNotifyScreen`
  - File: `busmate_app/lib/presentation/parents_module/stopnotify/screen/stop_notify_screen.dart`

- Routes.dashBoard
  - Path: `/dashBoard`
  - Widget: `DashboardScreen`
  - File: `busmate_app/lib/presentation/parents_module/dashboard/screens/dashboard_screen.dart`

- Routes.driverScreen
  - Path: `/driverScreen`
  - Widget: `DriverScreen`
  - File: `busmate_app/lib/presentation/parents_module/driver_module/screen/driver_screen.dart`

---

## Common class-based navigations (Get.to / Get.toNamed used inline)
These screens are often navigated via `Get.to(() => Widget())` instead of a named route. Below are the commonly referenced UI screens, where they are invoked, and the file that contains the invocation.

> Note: the widget class may live in a separate file (often `add_xxx_screen.dart`), but here we list where the navigation call occurs to help you locate usage.

- `AddSchoolScreen`
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (button -> `Get.to(() => AddSchoolScreen())`)

- `SendNotification` / `send-notification` (UI)
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (Get.toNamed('/send-notification'))
  - Note: This is an ad-hoc named path used in places (`Get.toNamed('/send-notification')`) but may not be registered in `AppPages` — check `app_pages.dart` if you expect a named route definition.

- `AddBusScreen`
  - Invoked from: `busmate_web/lib/modules/SchoolAdmin/bus_management/bus_management_screen.dart` (Get.to(() => AddBusScreen()))

- `AddStudentScreen`
  - Invoked from: `busmate_web/lib/modules/SchoolAdmin/student_management/student_management_screen.dart` (Get.to(() => AddStudentScreen()))

- `AddDriverScreen`
  - Invoked from: `busmate_web/lib/modules/SchoolAdmin/driver_management/driver_management_screen.dart` (Get.to(() => AddDriverScreen()))

- `SelectBusScreen`
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (await Get.to(() => SelectBusScreen()))

- `PaymentHistoryScreen`
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/school_management/school_dialogue_widget.dart` (Get.to(() => PaymentHistoryScreen(...)))

- `PaymentManagement` (access)
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (Get.toNamed('/payment-management'))
  - Note: verify whether `/payment-management` is registered in `app_pages.dart` or used as an ad-hoc path.

- `SchoolAdminPaymentScreen`
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (Get.to(() => SchoolAdminPaymentScreen(schoolId)))

- `ViewBusStatusScreen`
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (Get.to(() => ViewBusStatusScreen()))

- `StudentManagementScreen`
  - Invoked from: `busmate_web/lib/modules/SuperAdmin/dashboard/dashboard_screen.dart` (Get.to(() => StudentManagementScreen()))

- Various other `Get.to` calls in multiple dashboard and management screens (Search the codebase for `Get.to(` to find more class-based navigations).

---

## Notes & Next Steps
- There are some `Get.toNamed('/some-path')` usages that may be ad-hoc strings and not present in `AppPages.routes`. If you rely on named routing consistency, consider registering those paths in the appropriate `AppPages` file.
- To produce a fully exhaustive mapping (including every class-based widget file), I can traverse each `Get.to(...)` usage and locate the target widget's file definition. Tell me if you want that exhaustive cross-reference.
- If you'd like, I can also update `app_pages.dart` to include the missing ad-hoc named routes found in the codebase.

---

## Quick commands to find navigations locally
```powershell
# Find all named Get routes
Select-String -Path . -Pattern "GetPage\(|Get.toNamed\(|Get.offAllNamed\(|Get.to\(|Get.offNamed\(" -SimpleMatch -List

# List all occurrences of Get.to to inspect inline navigations
Select-String -Path . -Pattern "Get.to(" -AllMatches
```

If you want, I can now (1) expand this file to include the exact widget file for each class-based navigation, or (2) add any missing named routes into `app_pages.dart` automatically. Which would you like next?