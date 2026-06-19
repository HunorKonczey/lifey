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
# Without an explicit cap, the JVM sizes its default heap off the host's
# *full* visible memory when the platform doesn't enforce a hard cgroup
# limit (Railway's free tier just kills the container on overuse instead of
# constraining it at the OS level) — so it creeps toward however much RAM
# the underlying machine has, not the plan's actual allowance. Bounding it
# explicitly keeps total RSS (heap + metaspace + threads + native) well
# under a 1 GB plan; override JAVA_OPTS in Railway's env vars to retune
# without rebuilding.
ENV JAVA_OPTS="-Xms128m -Xmx384m -XX:MaxMetaspaceSize=128m"
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
