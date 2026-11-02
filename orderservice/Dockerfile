# Dockerfile for Order Service (Spring Boot with Java)
# Multi-stage build: first stage builds the JAR, second stage runs it

# Stage 1: Build stage
# Use official Maven image with Java 21 for building the application
FROM maven:3.9-eclipse-temurin-21 AS build

# Set working directory inside the container
WORKDIR /app

# Copy Maven configuration files first (better Docker layer caching)
# If pom.xml hasn't changed, Docker can use cached dependency layers
COPY pom.xml .
COPY .mvn .mvn
COPY mvnw .
COPY mvnw.cmd .

# Download all Maven dependencies
# This step is cached if pom.xml hasn't changed
RUN mvn dependency:go-offline -B

# Copy all source code to the container
COPY src ./src

# Build the application and create executable JAR
# -DskipTests: skip running tests during build (faster builds)
# clean: removes previous build artifacts
# package: compiles code and packages it into a JAR file
RUN mvn clean package -DskipTests

# Stage 2: Runtime stage
# Use smaller JRE-only image (no Maven or build tools)
FROM eclipse-temurin:21-jre-alpine AS runtime

# Set working directory for the runtime
WORKDIR /app

# Copy the built JAR file from build stage to runtime stage
# This keeps the final image small by excluding Maven and source code
COPY --from=build /app/target/*.jar app.jar

# Expose port 5003 - this is where the Order Service listens
# Must match server.port in application.properties
EXPOSE 5003

# Add health check to monitor service health
# Spring Boot Actuator provides /actuator/health endpoint
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5003/actuator/health || exit 1

# Start the Spring Boot application when container runs
# java -jar runs the executable JAR file
ENTRYPOINT ["java", "-jar", "app.jar"]
