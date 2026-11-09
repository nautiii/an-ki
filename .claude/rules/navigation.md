---
paths:
  - "lib/app/router/**"
  - "lib/app/shell/**"
  - "lib/core/routing/**"
---

# Navigation — go_router

go_router 17.5.0, pinned: 18.x needs the `material_ui` split (decision D9). Patterns:
architecture skill, `references/patterns.md` §12.

- Paths are constants in `core/routing/app_routes.dart`. The table mapping them to screens is
  `appRouterProvider` in `app/router/app_router.dart`, the only file that imports the screens of
  several features. A new page: its path in `AppRoutes`, its `GoRoute` in the table, a router
  test.
- Features navigate by path, never by importing another feature's screen: `context.go` moves to
  a place (a tab, or a sub-page whose stack follows the path: `/auth` then `/auth/login`),
  `context.push` opens a page above the current tab (settings, search),
  `context.pop` comes back.
- Access chooses the screen, not the code that signs in or out: the router re-runs the pure
  `accessRedirect` whenever `authAccessProvider` changes (`refreshListenable`). Never `go` after a
  sign-in, a sign-out or an unlock.
- Tabs are branches of the `StatefulShellRoute`, one per module of the registry
  (`app/modules/module_registry.dart`), all declared. `ShellBranches` keeps the branch of every
  running module mounted and cross-fades the current one, so a tab keeps its scroll and state; a
  disabled module's branch is unmounted (screens and subscriptions released) and reopens at its
  root. The bar shows the running modules (`runningModulesProvider`); one module, no bar. A page
  pushed from a tab (`/settings`, `/search`) is a top-level route that covers the tabs.
- Modules gate their paths: after `accessRedirect`, the pure `moduleRedirect` sends a location
  under an inactive module's `rootPath` to the first active module's root, and the shell says
  « Le module Livres est désactivé · Activer » (`moduleRedirectNoticeProvider`). While the profile
  loads (`activeModulesProvider` null) it returns null: wait, never redirect early. The router
  re-runs its redirects when access changes or the activation becomes known — not on every
  module change: go_router re-runs a refresh on the base location of the stack, which would
  replace pages pushed above the tab. A module turned off under an open page is left by the
  shell itself (`MainShell`), once it is back in front.
- Signed-in screens sit in a shell branch: `showModalBottomSheet(useRootNavigator: true)`, or the
  sheet opens inside the tab, under the floating bar. Dialogs already use the root navigator.
  Sheets and dialogs stay on `Navigator` (`Navigator.pop(context)`).
- Notification taps arrive through `NotificationService` (cold start included) and are routed by
  `app/bootstrap/app_initializer.dart`: « Souhaiter » goes to `/birthdays`, then opens the share
  sheet; a tap on the notification itself pushes the person page (`AppRoutes.person(id)`) above
  the current screen. A route a notification opens must work from a cold start, behind the
  redirects. A page addressed by id (`/person/:id`) handles an id it can't find (deleted, other
  account) with its own message.
- Tests: `tester.pumpHarness(widget, routes: {AppRoutes.settings: …})` stands in for the pages a
  widget opens; the whole app with its redirects is `tester.pumpApp(auth: …)` then
  `tester.settleApp()` (`test/support/app_harness.dart`). In the French tests, go back by tapping
  `find.byType(BackButton)`: `tester.pageBack()` looks for an English tooltip.
