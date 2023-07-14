#### This project is for the Devops bootcamp exercise for 
#### "Build Tools and Package Managers" 

Ansible:
* It's assumed, that you will clone this repo in ~/Learning dir and Nexus will be run on localhost.
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