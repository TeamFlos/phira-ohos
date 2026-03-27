# Phira OHOS

## Configuration

mv `build-profile-nosigncfg.json5` to `build-profile.json5`, and request sign file on it.

## Additional WSL Configuration

If you are on Windows, use DevEco Studio to open this project, and compile the phira project via WSL, you can use this configuration to automatically copy the built library.

Create `local.properties` in the project root with the following required properties:

```properties
copyLibphira.enabled=true
libphira.src=\\wsl.localhost\Ubuntu-24.04\path\to\libphira.so
wsl.distro=Ubuntu-24.04
```

The build will fail if any of these properties are missing.
