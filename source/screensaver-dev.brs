#if DEV
' Dev builds of the screensaver app only: deploy.ps1 leaves this file out of release builds,
' because Roku doesn't allow Main in a screensaver (Static Analysis reads the source, so
' compiling it out isn't enough). Launching the sideloaded screensaver
' (tools\relaunch.ps1 -Screensaver) shows it straight away, signed in from the launch
' parameters because sideloading wiped the registry.
sub Main(args as dynamic)
    applyDevLaunchSettings(args)
    RunScreenSaver(args)
end sub
#end if
