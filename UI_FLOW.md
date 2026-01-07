# UI Flow Documentation

## Settings Page - Instance Section

```
┌────────────────────────────────────────┐
│         Settings                       │
├────────────────────────────────────────┤
│                                        │
│  Archive Instance                      │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │ Current Instance    ▼ Anna's... │ │ <- Dropdown selector
│  └──────────────────────────────────┘ │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │ Manage Instances          ⚙️     │ │ <- Opens management page
│  └──────────────────────────────────┘ │
│                                        │
│  General Settings                      │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │ Dark Mode              [Toggle]  │ │
│  └──────────────────────────────────┘ │
│                                        │
│  ... (rest of settings)                │
│                                        │
└────────────────────────────────────────┘
```

## Instance Management Page

```
┌────────────────────────────────────────┐
│  ← Manage Instances      [+] [⟳]      │ <- Add & Reset buttons
├────────────────────────────────────────┤
│                                        │
│  Archive Instances                     │
│                                        │
│  Drag to reorder priority. App tries  │
│  each enabled instance 2x before      │
│  moving to next.                       │
│                                        │
│  ╔════════════════════════════════╗   │
│  ║ ☰ 1  Anna's Archive (.org)    ║   │
│  ║      https://annas-archive.org ║   │
│  ║                         [ON] ❌║   │ <- Can't delete default
│  ╚════════════════════════════════╝   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 2  Anna's Archive (.gs)     │   │
│  │      https://annas-archive.gs  │   │
│  │                         [ON] ❌│   │
│  └────────────────────────────────┘   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 3  Anna's Archive (.se)     │   │
│  │      https://annas-archive.se  │   │
│  │                         [ON] ❌│   │
│  └────────────────────────────────┘   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 4  Anna's Archive (.li)     │   │
│  │      https://annas-archive.li  │   │
│  │                         [ON] ❌│   │
│  └────────────────────────────────┘   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 5  Anna's Archive (.st)     │   │
│  │      https://annas-archive.st  │   │
│  │                         [ON] ❌│   │
│  └────────────────────────────────┘   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 6  Anna's Archive (.pm)     │   │
│  │      https://annas-archive.pm  │   │
│  │                         [ON] ❌│   │
│  └────────────────────────────────┘   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 7  Welib.org                 │   │
│  │      https://welib.org          │   │
│  │                         [ON] ❌│   │
│  └────────────────────────────────┘   │
│                                        │
│  ┌────────────────────────────────┐   │
│  │ ☰ 8  My Custom Mirror  [Custom]│   │
│  │      https://my-mirror.com      │   │
│  │                         [ON] 🗑️│   │ <- Can delete custom
│  └────────────────────────────────┘   │
│                                        │
└────────────────────────────────────────┘
```

## Add Custom Instance Dialog

```
┌────────────────────────────────────────┐
│  Add Custom Instance                   │
├────────────────────────────────────────┤
│                                        │
│  Name                                  │
│  ┌──────────────────────────────────┐ │
│  │ My Custom Mirror                 │ │
│  └──────────────────────────────────┘ │
│                                        │
│  URL                                   │
│  ┌──────────────────────────────────┐ │
│  │ https://example.com              │ │
│  └──────────────────────────────────┘ │
│                                        │
│           [Cancel]  [Add]              │
│                                        │
└────────────────────────────────────────┘
```

## User Interaction Flow

### Selecting an Instance
1. User opens Settings page
2. Sees "Current Instance" dropdown
3. Taps dropdown → shows all enabled instances
4. Selects desired instance
5. ✓ Snackbar: "Instance changed successfully"
6. Future searches use selected instance

### Managing Instances
1. User opens Settings page
2. Taps "Manage Instances"
3. Sees list of all instances with priority numbers
4. Can perform actions:

   **Reorder:**
   - Long press on item
   - Drag to new position
   - Release
   - ✓ Priority automatically updated

   **Enable/Disable:**
   - Toggle switch on/off
   - ✓ Change persisted immediately

   **Add Custom:**
   - Tap [+] button
   - Enter name and URL
   - Tap "Add"
   - ✓ Snackbar: "Instance added successfully"

   **Delete Custom:**
   - Tap 🗑️ icon on custom instance
   - Confirm in dialog
   - ✓ Snackbar: "Instance deleted"

   **Reset:**
   - Tap [⟳] button
   - ✓ Snackbar: "Reset to default instances"

### Search with Automatic Failover
1. User searches for a book
2. App uses selected instance (or first enabled)
3. **If successful:** Results displayed immediately
4. **If failed:**
   - Retry on same instance (wait 500ms)
   - If still failed, try next enabled instance
   - Repeat for all enabled instances (2x each)
   - If all fail, show error message

## Failover Visualization

```
Search Initiated
       ↓
Try Instance 1 (Anna's .org)
       ↓
   [Attempt 1]
       ↓
    Success? ──Yes──→ ✓ Show Results
       ↓ No
   Wait 500ms
       ↓
   [Attempt 2]
       ↓
    Success? ──Yes──→ ✓ Show Results
       ↓ No
       ↓
Try Instance 2 (Anna's .gs)
       ↓
   [Attempt 1]
       ↓
    Success? ──Yes──→ ✓ Show Results
       ↓ No
   Wait 500ms
       ↓
   [Attempt 2]
       ↓
    Success? ──Yes──→ ✓ Show Results
       ↓ No
       ↓
   ... (continue with remaining instances)
       ↓
All instances failed?
       ↓
    ✗ Show Error
```

## Visual Elements

### Instance Card Elements
- **☰** - Drag handle (for reordering)
- **Number** - Priority order (1 = tried first)
- **Name** - Display name of instance
- **URL** - Base URL of instance
- **[Custom]** - Badge for custom instances
- **[Toggle]** - Enable/disable switch (Green = ON, Grey = OFF)
- **🗑️** - Delete button (only for custom instances)
- **❌** - Indicates can't delete (default instances)

### Color Scheme
- **Primary Actions**: Red (brand color)
- **Enabled State**: Green toggle
- **Disabled State**: Grey toggle
- **Custom Badge**: Blue background with blue text
- **Cards**: Theme-dependent (light/dark mode)

### Accessibility
- All interactive elements have appropriate touch targets (minimum 48x48dp)
- Icons have semantic meanings
- Text is readable in both light and dark modes
- Drag handles provide clear affordance for reordering
- Confirmation dialogs for destructive actions

## State Management

### Provider Hierarchy
```
ProviderScope
  ├─ instanceManagerProvider (Singleton)
  ├─ archiveInstancesProvider (FutureProvider)
  ├─ currentInstanceProvider (FutureProvider)
  └─ selectedInstanceIdProvider (StateProvider)
```

### Data Flow
```
User Action
     ↓
UI Widget
     ↓
InstanceManager
     ↓
Database (SQLite)
     ↓
State Update
     ↓
UI Rebuild
```

## Error Handling

### User-Facing Errors
1. **Invalid URL Format**
   - When: Adding custom instance with invalid URL
   - Action: Show snackbar "URL must start with http:// or https://"
   
2. **Cannot Delete Default Instance**
   - When: Attempting to delete built-in instance
   - Action: Show snackbar "Cannot delete default instances"
   
3. **All Instances Failed**
   - When: All enabled instances fail after retries
   - Action: Show error widget with retry button
   
4. **No Enabled Instances**
   - When: All instances are disabled
   - Action: Fall back to default instance automatically

### Developer Errors
- All exceptions logged to console
- Graceful fallbacks prevent app crashes
- Last exception is preserved and can be inspected
