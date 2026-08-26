# Dockerfile for ChalkBoard WebSocket Relay Server
FROM dart:stable AS build

WORKDIR /app
COPY . .

WORKDIR /app/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server/bin/server /app/bin/server

EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/app/bin/server"]
