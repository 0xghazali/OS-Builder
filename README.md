🚀 0x OS Builder

0x OS Builder is a script that helps you create your own Debian-based custom Linux distribution.
It asks for your OS name, tools you want to embed, and then automatically:

Configures live-build

Adds custom branding (boot splash + boot menu)

Injects user-selected tools into the ISO

Builds a bootable .iso you can use in VirtualBox, VMware, or on real hardware

⚡ Created by 0x

✨ Features

🖥️ Custom OS name & branding

🔒 Preinstalled security & dev tools (user choice)

🎨 Custom boot splash & boot menu

📀 Builds live ISO + installer ISO

💡 Easy to use, beginner-friendly


📦 Requirements

Debian-based build environment (e.g., Debian 12 Bookworm VM)

Installed dependencies:

sudo apt update
sudo apt install -y live-build curl wget git


🚀 Usage

Clone the repo:

git clone https://github.com/0xghazali/OS-Builder.git
cd 0xOS-Builder
chmod +x build.sh


Run the builder:

./build.sh


It will ask you:

Enter your custom OS name (e.g., 0xOS): 
Packages: nmap git wireshark aircrack-ng hydra


After build → you get:

your-os-name.iso

🛠️ Example

Building 0xOS with tools:

OS Name: 0xOS
Packages: nmap git wireshark aircrack-ng hydra


✅ Output file: 0xos.iso


⚡ Roadmap

 Add default XFCE desktop environment

 Add Kali-like themes/icons

 Predefined security toolsets (Pentest, Forensics, DevOps)

🐧 Credits

Built on top of Debian Live-Build

Script and branding by 0x
