package io.fluxzy.mobile.connect.vpn

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import android.util.Log
import io.fluxzy.mobile.connect.vpn.models.AppInfoData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

/**
 * Manages retrieval of installed applications for per-app VPN filtering.
 */
class InstalledAppsManager(private val context: Context) {
    companion object {
        private const val TAG = "InstalledAppsManager"
        private const val ICON_SIZE = 48 // pixels
        private const val ICON_QUALITY = 80 // PNG compression quality
    }

    /**
     * Retrieves list of installed applications.
     * @param includeSystemApps Whether to include system apps in the list.
     * @return List of AppInfoData sorted alphabetically by app name.
     */
    suspend fun getInstalledApps(includeSystemApps: Boolean = false): List<AppInfoData> {
        return withContext(Dispatchers.IO) {
            val pm = context.packageManager
            val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
            Log.d(TAG, "Total installed packages: ${packages.size}, includeSystemApps: $includeSystemApps")

            val filteredPackages = packages.filter { appInfo ->
                // Filter out own app
                appInfo.packageName != context.packageName &&
                // Filter system apps if requested
                (includeSystemApps || !isSystemApp(appInfo))
            }
            Log.d(TAG, "Filtered packages: ${filteredPackages.size}")

            val result = filteredPackages.mapNotNull { appInfo ->
                try {
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    val iconBase64 = getAppIconBase64(pm, appInfo.packageName)

                    AppInfoData(
                        packageName = appInfo.packageName,
                        appName = appName,
                        iconBase64 = iconBase64
                    )
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to get info for ${appInfo.packageName}", e)
                    null
                }
            }.sortedBy { it.appName.lowercase() }

            Log.d(TAG, "Returning ${result.size} apps")
            result
        }
    }

    /**
     * Checks if an application is a system app.
     */
    private fun isSystemApp(appInfo: ApplicationInfo): Boolean {
        return (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
    }

    /**
     * Gets the app icon as a Base64-encoded PNG string.
     */
    private fun getAppIconBase64(pm: PackageManager, packageName: String): String? {
        return try {
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            val scaledBitmap = scaleBitmap(bitmap)

            val stream = ByteArrayOutputStream()
            scaledBitmap.compress(Bitmap.CompressFormat.PNG, ICON_QUALITY, stream)
            val bytes = stream.toByteArray()

            // Recycle bitmaps to free memory
            if (bitmap != scaledBitmap) {
                bitmap.recycle()
            }
            scaledBitmap.recycle()

            Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to get icon for $packageName", e)
            null
        }
    }

    /**
     * Converts a Drawable to a Bitmap.
     */
    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }

        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else ICON_SIZE
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else ICON_SIZE

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)

        return bitmap
    }

    /**
     * Scales a bitmap to the target icon size.
     */
    private fun scaleBitmap(bitmap: Bitmap): Bitmap {
        if (bitmap.width == ICON_SIZE && bitmap.height == ICON_SIZE) {
            return bitmap
        }
        return Bitmap.createScaledBitmap(bitmap, ICON_SIZE, ICON_SIZE, true)
    }
}
