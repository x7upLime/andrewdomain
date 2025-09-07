---
title: "Idm_install En"
date: 2025-08-16T11:52:49+02:00
draft: true
---

Idm stands for Identity Management, it is also known as FreeIPA. 
It also stands for "huge bundle of services that are generally used to manage 
identity and access (IAM) across an infrastructure".

The big bundle style of shipping software has its pros and cons.  
One argument that I would have against installing software this way is that
then you generally lose touch of what there is underneath. In this particular case tho,
it is a good thing because undestanding and configuring the services beneath is
objectively difficult unless you have a certain level of experience, and
FreeIPA does a wonderful job in condensing all the configuration in
just a couple of parameters that you pass interactively to an installer that
works like a charm and hides all the complexity away from you.

Of course then you also have a nice python web app to 
operate all the services. Nice.

## Requisites
hostnamectl set-hostname <hostname>.<domain>  

``` /etc/hosts
<IP> <hostname>.<domain>
<hostname>.<domain> <IP>
```

Open firewall if you have one.
Check with systemctl list-units --all for firewalld

RHEL also understands the freeipa-ldaps firewall services, which are a 
huge collection of ports.
```bash
# firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldaps
# firewall-cmd --add-service=freeipa-ldap --add-service=freeipa-ldaps --permanent
```

You can install freeipa on Fedora or rhel. 
Under rhel, the subscriptions for freeipa are integrated in the standard rhel subscription.  
**dnf install freeipa-server freeipa-sever-dns**  
**ipa-server install**  

## Services management
There is a huge list of services here that you can manage with systemctl.

Or there is a special wrapper called **ipa**:
systemctl start ipa
systemctl stop ipa
systemctl restart ipa
ipactl status

## How to use the certificates from the CA
Given an IdM server rhel96-utility.jacket.lime.
To download and trust the default CA of IdM, fire up the following commands:  
```bash
curl http://rhel96-utility.jacket.lime/ipa/config/ca.crt -o ~/ipa-ca.crt
sudo cp ~/ipa-ca.crt /etc/pki/ca-trust/source/anchors
sudo update-ca-trust
```

Then you can generate a certificate from the web app.

If generating with certutil:  
mkdir service-database
certutil -N -d service-database
certutil -R -d service-database -a -g <key size> -s 'CN=...,O=... -8 ... # Follow the instructions
\# Then you paste the csr and emit a certifcate. Copy the certificate in a file called host.crt
certutil -A -d service-database -n "nickname" -t u,u,u -i host.crt # adds the crt to the database
pk12util -o host.p12 -n "mytls" -d service-database # exports key+cert in p12 format
openssl pkcs12 -in host.p12 -nocerts -nodes -out host.key # extracts the key in clear
openssl pkcs12 -in host.p12 -clcerts -nokeys -out host.crt # extracts the cert in clean (pem format)

If generating with openssl:  
......

## References
 + [FreeIPA quickstart](https://www.freeipa.org/page/Quick_Start_Guide)
 + [Idm services mgmt](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/accessing_identity_management_services/viewing-starting-and-stopping-the-ipa-server_accessing-idm-services)
