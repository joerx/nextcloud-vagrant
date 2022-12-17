# Nextcloud on Vagrant

## Notes

- Uses `libvirt` as provider because it's faster (and more fun) than VirtualBox 
- Box is using Debian 11 since Ubuntu provides no `libvirt` boxes
- File sharing uses NFS, requires additional setup (not covered here)
- Uses self-signed certs, browser warnings are inevitable
- This uses some insecure settings, strictly for development only

## Usage

Start the VM, then open https://localhost:4443/ in a web browser, ignore SSL warnings.

```bash
vagrant up
```
