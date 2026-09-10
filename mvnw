#!/bin/sh
# Maven Wrapper launcher. The wrapper JAR is downloaded on first use rather
# than relying on a machine-wide Maven installation.
set -eu

BASE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WRAPPER_DIR="$BASE_DIR/.mvn/wrapper"
WRAPPER_JAR="$WRAPPER_DIR/maven-wrapper.jar"
WRAPPER_URL=https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/3.3.4/maven-wrapper-3.3.4.jar

if [ ! -r "$WRAPPER_JAR" ]; then
  mkdir -p "$WRAPPER_DIR"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error "$WRAPPER_URL" -o "$WRAPPER_JAR"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet "$WRAPPER_URL" -O "$WRAPPER_JAR"
  else
    echo "Error: curl or wget is required to download Maven Wrapper." >&2
    exit 1
  fi
fi

exec java ${JAVA_OPTS:-} -classpath "$WRAPPER_JAR" \
  "-Dmaven.multiModuleProjectDirectory=$BASE_DIR" \
  org.apache.maven.wrapper.MavenWrapperMain "$@"
