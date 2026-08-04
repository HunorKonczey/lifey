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
# Without an explicit cap, the JVM sizes its default heap off the host's
# *full* visible memory when the platform doesn't enforce a hard cgroup
# limit — so it creeps toward however much RAM the underlying machine has,
# not the plan's actual allowance, and the platform kills the container on
# overuse rather than constraining it.
#
# Sized for Render's 512 MB instances (both Free and Starter): total RSS is
# heap + metaspace + thread stacks + code cache + other native, so the heap
# cap has to sit well below the limit, not at it. Override JAVA_OPTS in the
# Render environment to retune on a bigger plan without rebuilding.
#
# Metaspace is the binding constraint here, not the heap. The Firebase Admin
# SDK (gRPC + protobuf + the Google API client) loads a very large number of
# classes when `firebaseApp` is created, and a 96m cap died with
# `OutOfMemoryError: Metaspace` mid-startup. Give metaspace the larger share
# and keep the heap modest — this app's biggest transient allocation is a
# decoded upload image (multipart is capped at 10MB), not steady-state data.
ENV JAVA_OPTS="-Xms64m -Xmx192m -XX:MaxMetaspaceSize=192m -XX:ReservedCodeCacheSize=48m -XX:MaxDirectMemorySize=32m"
# Neither Render nor Railway has a secret-file mount, so push credentials are
# supplied as base64-encoded env vars and decoded to a file here on startup.
# Each block is a no-op when its *_B64 var is unset, so a deploy with push
# disabled boots exactly as before. See devops/deploy-backend-render.md.
ENTRYPOINT ["sh", "-c", "\
  if [ -n \"$PUSH_FCM_CREDENTIALS_B64\" ]; then echo \"$PUSH_FCM_CREDENTIALS_B64\" | base64 -d > \"${PUSH_FCM_CREDENTIALS_PATH:-/tmp/firebase.json}\"; fi; \
  if [ -n \"$PUSH_APNS_KEY_B64\" ]; then echo \"$PUSH_APNS_KEY_B64\" | base64 -d > \"${PUSH_APNS_KEY_PATH:-/tmp/apns.p8}\"; fi; \
  java $JAVA_OPTS -jar app.jar"]
