# Photo Tidy - 马桶伴侣

A SwiftUI iOS app that helps users manage and declutter their photo library.

## Project Structure

```
PhotoTidy-Toilet Buddy/
├── PhotoTidyToiletBuddyApp.swift   # Main app entry point (AdMob initialization)
├── ContentView.swift                # Main view controller (View flow management)
├── SessionSetupView.swift           # Session setup screen (F-02, F-03.1)
├── CardReviewView.swift             # Core photo review interface (A-01, A-03, F-06)
├── SessionCompleteView.swift        # Session completion summary (Ad trigger)
├── AdvancedFilterView.swift         # Advanced filter settings (F-03.1)
├── TidySessionViewModel.swift       # Core state management (ViewModel + Ad counter)
├── PhotoService.swift               # Photos framework service
├── AdManager.swift                  # AdMob integration manager
├── Info.plist                       # App configuration
├── Assets.xcassets/                 # App assets
└── Podfile                          # CocoaPods dependencies
```

## Features

- **Photo Library Access**: Access and manage user's photo library with proper permissions
- **Random Photo Selection**: True random selection using Fisher-Yates shuffle algorithm
- **Advanced Filtering**: Filter photos by type, favorites, hidden status, and content subtypes
- **Photo Management**: Delete photos with batch operations support
- **Privacy First**: All operations performed locally on device
- **AdMob Integration**: Monetization through Google AdMob

## Configuration

### Privacy Permissions

The app includes the following privacy permissions in `Info.plist`:

- **Photo Library Access**: "Photo Tidy - 马桶伴侣需要访问您的相册，以便随机选取照片供您审阅和删除。所有操作均在本地进行。"

### AdMob Setup

The project includes placeholder AdMob IDs for testing:

- **App ID**: `ca-app-pub-2034595640300550~4044769988` (Production ID)
- **Interstitial Ad Unit ID**: `ca-app-pub-2034595640300550/4965494634` (Production ID)

**⚠️ IMPORTANT**: Replace these placeholder IDs with your actual AdMob IDs before releasing to production!

## Installation

1. Install CocoaPods dependencies:
   ```bash
   cd /Users/devfang/Cursor/photo_tidy_toilet_buddy
   pod install
   ```

2. Open the workspace (not the project):
   ```bash
   open PhotoTidy-Toilet\ Buddy.xcworkspace
   ```

3. Build and run the app in Xcode

## Requirements

- iOS 14.0+
- Xcode 15.0+
- CocoaPods
- Swift 5.0+

## Architecture

### Views

#### SessionSetupView (F-02, F-03.1)

The session setup screen where users configure their photo review session:

**Features:**
- **Title Display**: "Photo Tidy - 马桶伴侣" with modern gradient icon
- **Photo Count Selection (F-02)**:
  - Slider: 10-500 photos with smooth animation
  - Preset buttons: Quick (10), Standard (30), Deep (50)
  - Real-time count display with gradient styling
- **Quick Filters**:
  - Toggle: Exclude hidden photos
  - Toggle: Exclude favorite photos
- **Advanced Filter Entry (F-03.1)**:
  - Navigation button to `AdvancedFilterView`
  - Shows current filter selection
- **Session Statistics**:
  - Displays previous session results when completed
  - Shows deleted and kept photo counts
- **Start Button**:
  - Gradient button with shadow effect
  - Calls `viewModel.startNewSession()` with selected parameters

#### CardReviewView (A-01, A-03, F-06)

The core photo review interface with card-based interactions:

**Photo Card Display:**
- Full-screen immersive black background
- High-quality photo rendering (1200x1200)
- Smooth loading animations
- **Double-tap to zoom (A-01)**: 2x zoom with spring animation

**Gesture Navigation:**
- **Swipe left**: Navigate to next photo (`moveToNextPhoto()`)
- **Swipe right**: Navigate to previous photo (`moveToPreviousPhoto()`)
- Visual direction hints during dragging
- Rotation effect based on drag distance
- Threshold-based gesture recognition (100pt)
- **Note**: Gestures for navigation only, not for delete decisions

**Top Status Bar:**
- Progress indicator with gradient bar (Blue → Purple)
- Current/total photo counter
- Photo metadata:
  - Creation date and time
  - Resolution (width × height)
  - Video duration (for videos)
- Statistics badges (deleted/kept counts)
- **Undo button (A-03)**:
  - Orange themed
  - Only enabled when `deletedCount > 0`
  - Calls `viewModel.undoLastDeletion()`
- Close button (X) to end session

**Bottom Action Buttons (F-06):**
- **Delete button (Left)**:
  - Large circular button (70pt)
  - Red gradient with shadow
  - Trash icon
  - Easy single-handed reach
  - Calls `deleteCurrentPhoto()`
- **Keep button (Right)**:
  - Large circular button (70pt)
  - Green gradient with shadow
  - Thumbs-up icon
  - Easy single-handed reach
  - Calls `keepCurrentPhoto()`
- Scale animation on press

**Visual Feedback:**
- **Delete action**:
  - Card flies out to the left
  - Red flash overlay (30% opacity)
  - Haptic feedback (medium impact)
  - Smooth spring animation
  - Fade out effect
- **Keep action**:
  - Green flash overlay (20% opacity)
  - Haptic success feedback
  - Immediate transition
- **Drag interaction**:
  - Card rotation during drag
  - Scale effect based on distance
  - Opacity fade on edges
  - Direction indicators

**Animations:**
- Spring physics for natural feel
- Zoom animation: `spring(response: 0.4, dampingFraction: 0.8)`
- Delete animation: `spring(response: 0.5, dampingFraction: 0.8)`
- Drag animation: `spring(response: 0.3, dampingFraction: 0.7)`
- All transitions smooth and responsive

**State Management:**
- Automatic photo loading on index change
- Loading state with spinner
- Error state handling
- Zoom state (tap to zoom in/out)
- Drag state tracking
- Delete animation state

#### SessionCompleteView

Session completion summary screen with ad integration:

**Statistics Display:**
- Animated success icon (green checkmark with spring animation)
- Session completion message
- Detailed statistics cards:
  - Deleted count (red theme)
  - Kept count (green theme)
  - Total reviewed (blue theme)
- Animated number reveals

**Session Details:**
- Deletion percentage
- Keep percentage
- Completed session counter
- Progress tracking

**Ad Integration:**
- Checks `viewModel.shouldShowAd()` before starting new session
- Shows interstitial ad every 3 completed sessions (configurable)
- Ad dismissal callback triggers session reset
- Graceful fallback if ad not ready

**Start New Session Button:**
- Gradient button (Blue → Purple)
- Triggers ad check logic
- Seamless transition to `SessionSetupView` after ad
- Disabled state during ad display

**UI/UX:**
- Gradient background (white → light blue)
- Spring animations for stats reveal
- Clean card-based layout
- Success-themed color palette

#### AdvancedFilterView (F-03.1)

Detailed filtering options for photo selection:

**Content Type Selection:**
- All photos
- Screenshots only
- Panoramas only
- Live Photos only
- Portrait mode only
- Burst photos only
- Videos only

Each option includes:
- Icon representation
- Descriptive text
- Visual selection state with checkmark

**Exclusion Options:**
- Exclude hidden photos (with toggle)
- Exclude favorite photos (with toggle)

**Preview Section:**
- Real-time display of current filter settings
- Clear visual feedback of selected options

**UI/UX:**
- Modal sheet presentation
- Cancel/Done buttons
- Smooth animations and transitions
- Accessible design with SF Symbols

### TidySessionViewModel

The `TidySessionViewModel.swift` is the core state management layer using SwiftUI's `@MainActor` and `ObservableObject`:

**Data Models:**
- `TidyPhoto`: Wrapper struct containing `id` and `PHAsset`

**State Properties:**
- `photosToReview: [TidyPhoto]` - Photos queue for current session
- `currentIndex: Int` - Current photo being viewed
- `deletedCount: Int` - Number of photos deleted
- `keptCount: Int` - Number of photos kept
- `lastDeletedAsset: PHAsset?` - Last deleted photo for undo
- `isSessionActive: Bool` - Session status
- `isSessionCompleted: Bool` - Whether all photos reviewed

**Core Methods:**
- `startNewSession(count:contentSubtypes:excludeHidden:excludeFavorite:)` - Initialize new review session
- `deleteCurrentPhoto()` - Delete current photo and advance
- `keepCurrentPhoto()` - Keep current photo and advance
- `moveToPreviousPhoto()` / `moveToNextPhoto()` - Gesture-driven navigation
- `undoLastDeletion()` - Undo last delete operation

**Session Management:**
- `resetSession()` - Clear all session data
- `pauseSession()` / `resumeSession()` - Pause/resume functionality
- `endSession()` - Complete and finalize session

**Computed Properties:**
- `currentPhoto`, `totalPhotos`, `remainingPhotos`, `progress`, `canUndo`, etc.

### PhotoService

The `PhotoService.swift` file provides comprehensive photo library management:

**Permission Management:**
- `checkAndRequestPermissions()`: Async function to check and request photo library access
- `hasPhotoLibraryAccess()`: Check current permission status

**Random Photo Selection:**
- `fetchRandomAssets(count:contentSubtypes:excludeHidden:excludeFavorite:)`: Fetch random photos with advanced filtering
  - Uses `PHFetchOptions` with `NSPredicate` for filtering
  - Implements Fisher-Yates shuffle algorithm for true randomness
  - Supports filtering by media subtypes, hidden status, and favorites

**Photo Management:**
- `deleteAsset(asset:completion:)`: Delete a single photo
- `deleteAssets(assets:completion:)`: Batch delete multiple photos
- `restoreAsset(asset:completion:)`: Attempt to restore deleted photos (Note: iOS limitations apply)

**Helper Methods:**
- `fetchThumbnail(for:targetSize:completion:)`: Get photo thumbnails
- `getAssetInfo(asset:)`: Get detailed asset information
- `getLibraryStatistics()`: Get photo library statistics

### AdManager

The `AdManager.swift` file provides complete AdMob integration:

**Initialization:**
- `initializeAdMob()`: Initialize AdMob SDK on app launch
- Automatically preloads first ad after initialization
- Logs adapter status for debugging

**Ad Loading:**
- `loadInterstitialAd()`: Preload interstitial ads
- Uses test Ad Unit ID (replace before production)
- Error handling with fallback
- Automatic reload on dismissal

**Ad Display:**
- `showInterstitialAd(completion:)`: Show interstitial ad
- Completion callback executed after ad dismissal
- Graceful handling if ad not ready
- Window scene support for iOS 13+

**Delegate Methods:**
- `adDidDismissFullScreenContent`: Auto-reload next ad
- `adDidFailToPresentFullScreenContentWithError`: Error handling
- `adWillPresentFullScreenContent`: Pre-display hook
- `adDidRecordImpression`: Impression tracking
- `adDidRecordClick`: Click tracking

**Features:**
- Singleton pattern (`shared` instance)
- Thread-safe callbacks
- Chinese debug logging
- Production-ready error handling

### Ad Frequency Logic

**In TidySessionViewModel:**
- `sessionCounter`: Tracks completed sessions
- `adFrequency = 3`: Show ad every 3 sessions
- `shouldShowAd()`: Returns true when `sessionCounter % adFrequency == 0`
- Counter increments in `endSession()`

**Flow:**
1. User completes session → `sessionCounter++`
2. User clicks "Start New Session" → Check `shouldShowAd()`
3. If true → Show ad → On dismissal → Reset session
4. If false → Directly reset session

## App Flow

```
App Launch
    ↓
PhotoTidyToiletBuddyApp (AdMob init)
    ↓
ContentView (View Router)
    ↓
SessionSetupView (Configure)
    ↓
User taps "Start"
    ↓
CardReviewView (Review photos)
    ↓
User reviews all photos
    ↓
SessionCompleteView (Summary)
    ↓
User taps "Start New Session"
    ↓
Check sessionCounter
    ├─ Modulo 3 == 0? → Show Ad → After ad → SessionSetupView
    └─ Otherwise → Direct to SessionSetupView
```

## App Display Name

The app's display name is configured as **"Photo Tidy"** in `Info.plist`.

## License

© 2025 Photo Tidy. All rights reserved.

