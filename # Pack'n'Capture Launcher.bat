copy Win32\Release\FMXL3.exe "[x32] FMXL3.exe" /B /Y
copy Win64\Release\FMXL3.exe "[x64] FMXL3.exe" /B /Y
"# Stuff\upx.exe" -9 "[x32] FMXL3.exe"
"# Stuff\upx.exe" -9 "[x64] FMXL3.exe"