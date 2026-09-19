using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class WinUtilLauncher
{
    [STAThread]
    private static int Main()
    {
        var scriptPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "winutil.ps1");
        if (!File.Exists(scriptPath))
        {
            MessageBox.Show("WinUtilLauncher.exe must be kept in the same folder as winutil.ps1.", "WinUtil", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell\\v1.0\\powershell.exe"),
                Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -File \"" + scriptPath + "\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            });
            return 0;
        }
        catch (Exception exception)
        {
            MessageBox.Show("WinUtil could not be started.\r\n\r\n" + exception.Message, "WinUtil", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}
