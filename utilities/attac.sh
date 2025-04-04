#!/bin/sh
yay --noconfirm -Sy \
remmina \
socat \
go \
proxychains-ng \
nmap \
masscan \
impacket \
metasploit \
sqlmap \
john \
medusa \
ffuf \
seclists \
ldapdomaindump \
binwalk \
evil-winrm \
responder \
certipy \
httpx \
dnsx \
nuclei \
subfinder \
strace \
apachedirectorystudio

mkdir -p /opt/workspace/wordlists /opt/workspace/linux /opt/workspace/windows /opt/workspace/peassng /opt/workspace/chisel /opt/workspace/c2/sliver
wget http://downloads.skullsecurity.org/passwords/rockyou.txt.bz2 -O /opt/workspace/wordlists/rockyou.bz2
wget https://github.com/interference-security/kali-windows-binaries/archive/refs/heads/master.zip -O /opt/workspace/windows/binaries.zip
wget https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/archive/refs/heads/master.zip -O /opt/workspace/windows/ghostpack_binaries.zip
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/linpeas.sh -O /opt/workspace/peassng/linpeas.sh
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/winPEAS.bat -O /opt/workspace/peassng/winPEAS.bat
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/winPEASx64.exe -O /opt/workspace/peassng/winPEASx64.exe
wget https://github.com/carlospolop/PEASS-ng/releases/download/20250401-a1b119bc/winPEASx86.exe -O /opt/workspace/peassng/winPEASx86.exe
7z a /opt/workspace/peassng/peassng.7z /opt/workspace/peassng/* && rm -f /opt/workspace/peassng/lin* && rm -f /opt/workspace/peassng/win*
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_linux_amd64.gz -O /opt/workspace/chisel/chisel_1.9.1_linux_amd64.gz
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_windows_amd64.gz -O /opt/workspace/chisel/chisel_1.9.1_windows_amd64.gz
wget https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_windows_386.gz -O /opt/workspace/chisel/chisel_1.9.1_windows_386.gz
wget https://github.com/BishopFox/sliver/releases/download/v1.5.43/sliver-server_linux -O /opt/workspace/c2/sliver/sliver-server
wget https://github.com/BishopFox/sliver/releases/download/v1.5.43/sliver-client_linux -O /opt/workspace/c2/sliver/sliver-client
7z a /opt/workspace/c2/sliver/sliver.7z /opt/workspace/c2/sliver/* && rm -f /opt/workspace/c2/sliver/sliver-*
