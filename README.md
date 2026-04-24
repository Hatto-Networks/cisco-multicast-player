# cisco-multicast-player
This bash script lets you stream audio to Cisco IP Phones. 

Most Cisco enterprise phones have a feature to play live audio via multicast RTP, primarily for paging. This script sets up a RTP server using VLC and sends a POST request to defined phone(s) to start listening to the stream.

# Instructions
These instructions are meant for Linux/Mac. You'll need [WSL](https://learn.microsoft.com/en-us/windows/wsl/about) to run this on Windows. 

First, install the required dependencies:
```
# Debian/Ubuntu:
sudo apt install -y curl ffmpeg vlc

# Arch Linux:
sudo pacman -Sy curl ffmpeg vlc

# macOS:
brew install curl ffmpeg vlc
```
Clone the repo, and run `chmod +x ./broadcast.sh` inside the folder. That's it, you're done!

# Usage
To run without arguments, you'll need to:
- Create a folder called `audio` containing your audio files (see [here](https://ffmpeg.org/ffmpeg-formats.html) for compatible formats)
- Create a configuration file called `phones.conf` containing the IP address(es) of the phone(s) to play audio on (seperated by newline)

  - Example:
   ```
   192.168.1.1
   192.168.1.2
   1.1.1.1
   8.8.8.8
   ```
  and so on.
- **Optional**: Create a file called .broadcastauthorization containing base64-encoded credentials (for example, `username:password` translates to `dXNlcm5hbWU6cGFzc3dvcmQ=`) to authenticate with the phone. If this file is not created the script will authenticate with `admin:Cisco`.

Or, you can use arguments to specify options. See below for available arguments.

# Arguments
- `-i or --device-ip`: Specifies the IP address(es) of the phone(s) to play audio on. Specify multiple addresses with `,`.
  - Example: `-i 192.168.1.1,192.168.1.2,8.8.8.8` or `-i 192.168.1.1`
- `-f or --file`: Specifies a single file to play.
  - Example: `-f ./opusno1.mp3`
- `-d or --directory`: Specifies a directory to play audio from.
  - Example: `-d /home/user/Music`
- `-c or --credentials`: Specifies credentials to use with the phone's web server. Defaults to `admin:Cisco`.
  - Example: `-c username:password`
- `-m or --multicast-ip`: Sets the IP address to broadcast on. Defaults to `239.255.255.250`.
  - Example: `-m 239.0.0.1`
- `-p or --multicast-port`: Sets the UDP port to broadcast on. Defaults to `20480`.
  - Example: `-p 20480`
- `-s or --shuffle`: Shuffles audio files in a folder. Not applicable when playing one file.
- `-r or --repeat`: Repeats playback of an audio file, or all audio files in a folder.
- `-v or --verbose`: Enables verbose mode on FFMPEG and VLC.
- `-n or --nocleanup`: Keeps temporary directories. You'd only want to use this for debugging.

# Credits
- Initially written by [Jarynnnn](https://github.com/Jarynnnn)
- Updated and modified by [dotbrew](https://github.com/akidinatophat)
  
