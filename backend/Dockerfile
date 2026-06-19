# Build stage
FROM eclipse-temurin:24-jdk AS build
WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
# git on Windows doesn't track the executable bit, so a checkout from there
# (or any checkout where it got lost) leaves mvnw non-executable in the build
# context regardless of what's committed — set it explicitly rather than
# relying on the committed mode.
RUN chmod +x mvnw
RUN ./mvnw dependency:go-offline -B
COPY src ./src
RUN ./mvnw clean package -DskipTests -B

# Runtime stage
FROM eclipse-temurin:24-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
