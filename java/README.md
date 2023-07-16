#### This project is for the Devops bootcamp exercise for 
#### "Build Tools and Package Managers" 

Ansible:
* It's assumed, that you will clone this repo in ~/Learning dir and Nexus will be run on localhost.
* To quickly spin-up EC2, please, use terraform with your IP address provided on command line, it's also assumed to use tour default SSH, then paste output EC2 IP into ansible/hosts file to build & deploy app. Example: `terraform apply -var 'my_ip=187.190.247.121/32'`
* In build-deploy-playbook you need to provide username var on a command line, i.e. `ansible-playbook -i hosts playbook.yaml -e "username=dev"`
* To get Nexus up and running use `docker run -d -p 8081:8081 --name nexus -v nexus-data:/nexus-data sonatype/nexus3`
* To get Nexus admin password do:
```
docker exec -u 0 -it <Nexus container ID> bash
cat sonatype-work/nexus3/admin.password
```
* Now you need to create new Maven repo named "maven-project-repo" with admin user
* In push-to-nexus-playbook you need to provide following vars on command line: username, password, appVersion, example:
```
ansible-playbook -i hosts push-to-nexus-playbook.yaml -e "username=admin" -e "password=12345678" -e "appVersion=2.1" --connection=local
```