# OpenMark Cairo Smart Contracts

## Quickstart

Before you begin, ensure you have the following tools installed:

- [Node (>= v18.17)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))

### Install Scarb

```sh
$ scarb --version

scarb 2.8.0
cairo: 2.8.0
sierra: 1.6.0

$ universal-sierra-compiler --version
universal-sierra-compiler 2.2.0
```

1. Add the Scarb plugin:

    ```bash
    asdf plugin add scarb
    ```

2. Install the specific version (e.g., 2.8.0):

    ```bash
    asdf install scarb 2.8.0
    ```

3. Set the global version:

    ```bash
    asdf global scarb 2.8.0
    ```

Alternatively, you can install Scarb using the following command:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh -s -- -v 2.8.0
```

### Run tests

```bash
npm run test
```

## API Document

For a detailed API reference, please see the [API.md](./API.md) file.

## License

OpenMark Contracts for Cairo is released under the [MIT License](LICENSE).
