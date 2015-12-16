copy "Defence\Ratibor\RatiborLib\Win32\Release\RatiborLib.dll" "# Stuff\Defence\RatiborLib32.dll" /B /Y
copy "Defence\Ratibor\RatiborLib\Win64\Release\RatiborLib.dll" "# Stuff\Defence\RatiborLib64.dll" /B /Y
copy "Defence\Ratibor\RatiborInjector\Win32\Release\RatiborInjector.exe" "# Stuff\Defence\RatiborInjector32.exe" /B /Y
copy "Defence\Ratibor\RatiborInjector\Win64\Release\RatiborInjector.exe" "# Stuff\Defence\RatiborInjector64.exe" /B /Y

"# Stuff\upx.exe" -9 "# Stuff\Defence\RatiborLib32.dll"
"# Stuff\upx.exe" -9 "# Stuff\Defence\RatiborLib64.dll"
"# Stuff\upx.exe" -9 "# Stuff\Defence\RatiborInjector32.exe"
"# Stuff\upx.exe" -9 "# Stuff\Defence\RatiborInjector64.exe"

"# Stuff\brcc32.exe" "# Stuff\Defence.rc"
copy "# Stuff\Defence.res" Defence.res /B /Y

pause