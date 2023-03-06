FROM eclipse-temurin:17-jdk-alpine
VOLUME /tmp
ADD target/spring-boot-demo-0.0.1-SNAPSHOT.jar target/app.jar
ENTRYPOINT ["java","-jar","-Dspring.profiles.active=local","target/app.jar"]