FROM ubuntu:20.04

WORKDIR /app

RUN useradd -ms /bin/bash app-user && \
    apt update && \
    apt install -y default-jre

COPY --chown=app-user:app-user ./build/libs/bootcamp-java-mysql-project-1.0-SNAPSHOT.jar docker-entrypoint.sh /app/

USER app-user

ENTRYPOINT [ "./docker-entrypoint.sh" ]