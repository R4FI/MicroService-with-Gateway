# Dockerfile for User Management Service (.NET 9)
# Multi-stage build: first stage builds the app, second stage runs it

# Stage 1: Build stage
# Use official .NET 9 SDK image for building the application
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set working directory inside the container
WORKDIR /src

# Copy the project file first (better Docker layer caching)
# If the .csproj hasn't changed, Docker can use cached layers
COPY UserManagementService.csproj .

# Restore NuGet packages based on the project file
# This downloads all dependencies defined in the .csproj
RUN dotnet restore

# Copy all source files to the container
COPY . .

# Build the application in Release mode
# Output goes to /src/out directory
RUN dotnet publish -c Release -o /src/out

# Stage 2: Runtime stage
# Use smaller runtime-only image (no SDK tools, smaller size)
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Set working directory for the runtime
WORKDIR /app

# Copy built application from build stage to runtime stage
# This keeps the final image small by excluding SDK and source code
COPY --from=build /src/out .

# Expose port 5126 - this is where the User Management Service listens
# Must match the port in appsettings.json
EXPOSE 5126

# Set environment variable for ASP.NET Core to listen on all interfaces
# 0.0.0.0 allows connections from outside the container
ENV ASPNETCORE_URLS=http://+:5126

# Start the application when container runs
# Executes the compiled DLL
ENTRYPOINT ["dotnet", "UserManagementService.dll"]
