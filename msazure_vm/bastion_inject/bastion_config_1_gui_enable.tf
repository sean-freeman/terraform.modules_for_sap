# Note: If login uses root, you do not need "sudo" prefix or "sudo su - root -c 'command here'"
#       For AWS, MS Azure and GCP without initial root login the sudo elevated privilege is required

resource "null_resource" "bastion_config_1" {

  depends_on = [azurerm_linux_virtual_machine.bastion_host]

  # Specify the ssh connection
  connection {
    type        = "ssh"
    user        = "azvm-user"
    private_key = var.module_var_bastion_private_ssh_key
    host        = azurerm_public_ip.bastion_host_publicip.ip_address
  }

  # Path must already exist and must not use Bash shell special variable, e.g. cannot use $HOME/file.sh
  # "By default, OpenSSH's scp implementation runs in the remote user's home directory and so you can specify a relative path to upload into that home directory"
  # https://www.terraform.io/language/resources/provisioners/file#destination-paths
  provisioner "file" {
    destination = "bastion_config_1.sh"
    content     = <<EOF
#!/bin/bash

os_release=$(grep ^ID= /etc/os-release | cut -d '=' -f2 | tr -d '\"')
os_version=$(grep ^VERSION_ID= /etc/os-release)

if [ "$os_release" = 'rhel' ] || [ "$os_release" = 'centos' ]; then
  # Install GNOME GUI
  dnf --assumeyes --debuglevel=1 groupinstall "Server with GUI"
  systemctl set-default graphical.target
  systemctl default
fi

if [ "$os_release" = 'sles' ] || [ "$os_release" = 'sles_sap' ] ; then
  # Install GNOME GUI
  zypper --non-interactive install --no-confirm -t pattern gnome_basic
  systemctl set-default graphical.target
  systemctl default
fi

# Reboot
echo "Rebooting VM for changes to take effect"
(sleep 2 && sudo reboot)&

EOF
  }

  provisioner "remote-exec" {
    inline = [
      "echo '---- Sleep 20s to ensure bastion host is ready -----' && sleep 20",
      "chmod +x ./bastion_config_1.sh ; sudo su - root -c 'bash /home/azvm-user/bastion_config_1.sh'"
    ]
  }

}
