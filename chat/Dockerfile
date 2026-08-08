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
RUN groupadd --system app && useradd --system --gid app app
COPY --from=build --chown=app:app /app/target/*.jar app.jar
USER app
EXPOSE 8080
# Sized for Render's 512 MB instances, and MEASURED rather than guessed
# (docs/chat/44-chat-service-extraction-plan.md §17.4):
#
#   * Metaspace peaked at 99 MB with the prod profile after every endpoint had
#     been exercised — so the plan's original 96 MB cap was wrong, and a service
#     started with it booted fine and then died on the first request. 128 MB
#     leaves ~29 MB of headroom.
#   * That is still 64 MB less than lifey-api needs, and the reason is the whole
#     point of §6.1: the Firebase Admin SDK is not in this JVM. Push goes over
#     HTTP to the monolith, so the class-loading cost stays over there.
#   * Heap gets 192m. The long-lived SSE connections live here, but they are
#     cheap — 107 KB each, measured (plan §15.5) — so 200 concurrent chatters
#     is about 21 MB, and the binding constraint is ordinary request work.
#
# Override JAVA_OPTS in the Render environment to retune without a rebuild.
ENV JAVA_OPTS="-Xms64m -Xmx192m -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=48m -XX:MaxDirectMemorySize=32m"
# No secret-file decoding here, unlike lifey-api's entrypoint: this service holds
# no APNs key and no Firebase credentials, because it sends no push itself.
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
