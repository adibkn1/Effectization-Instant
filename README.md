# Effectization AR App Clip

AR App Clip that loads configurations from remote URLs for dynamically changing AR experiences.

## Recent Fixes

### Fixed URL/Configuration Handling:

1. **URL Parameter Extraction**
   - Now properly extracts folder IDs from URLs (e.g., "ar1" from "adagxr.com/card/ar1")
   - Supports any folder ID format (ar1, ar2, arxyz, etc.)
   - Works with path components or subdomains

2. **Configuration Loading Timing**
   - Fixed initialization sequence to ensure URL is processed before configuration
   - Added _XCAppClipURL environment variable detection at startup
   - Improved URL handling in SceneDelegate to prioritize environment variables

3. **UI Safety Improvements**
   - Added null checks to prevent crashes when animating UI components
   - Improved error handling for video downloads
   - Made file operations safer with proper error handling

4. **Video and CTA Button Fixes**
   - Fixed video caching to avoid file conflicts
   - Added explicit CTA button display when image is detected
   - Used unique filenames based on folder ID for caching

## How It Works

1. **URL Detection**: The App Clip scans the launch URL for folder IDs in the format "/card/[folderID]"
2. **Configuration Loading**: Loads JSON configuration from "https://adagxr.com/card/[folderID]/sample_config.json"
3. **AR Experience**: Shows the configured AR experience with appropriate video, image tracking, and CTA button

## Testing

Use XCScheme environment variable _XCAppClipURL to test different configurations:
- "https://adagxr.com/card/ar1" for the "ar1" configuration
- "https://adagxr.com/card/ar2" for the "ar2" configuration
- Etc. 