#### This project is for the Devops bootcamp exercise for 
#### "Containers - Docker" 
#### "Container Orchestration - K8s"
#### "Monitoring - Prometheus"

Nexus container
```
docker run -d \
-p 8082:8081 \
-p 8083:8083 \
--name nexus \
-v nexus-data:/nexus-data \
sonatype/nexus3
```

Configure role, user and realm (docker bearer access token) in nexus

Login to registry

`docker login http://0.0.0.0:8083`

Build image

`docker build -t 0.0.0.0:8083/java-app:1.0 .`

Push image to registry

`docker push 0.0.0.0:8083/java-app:1.0`

Env vars to export on server
```
export DB_USER=app-user
export DB_PWD=app-psw-12345
export DB_NAME=my-db
export DB_ROOT_PASSWORD=12345
```

Generate DockerHub secret config file:
```
kubectl create secret docker-registry docker-hub \
--docker-username=<username> \
--docker-password=<password> \
--dry-run=client \
-o yaml
```

For DB to deploy secret and configmap needed, illustrative examples are in k8s folder.

Install mySQL:
```
helm install -f helm/mysql/values-mysql-bitnami.yaml mysql-release bitnami/mysql -n my-app
helm uninstall mysql-release -n my-app
```

Install app:
`helm install -f helm/my-app/values-my-app.yaml my-app-release ./helm/my-app/my-app -n my-app`

Install ingress:
`helm install my-nginx-ingress ingress-nginx/ingress-nginx --set controller.publishService.enabled=true`