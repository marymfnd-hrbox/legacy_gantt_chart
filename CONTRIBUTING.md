# Contributing to Legacy Gantt Chart

Contributions are welcome! We appreciate your help in making this package even better.

## Reporting Bugs and Requesting Features

If you find a bug or have a feature request, please open an issue on our [GitHub issue tracker](https://github.com/barneysspeedshop/legacy_gantt_chart/issues). We have templates to help you provide the necessary information.

## Contributing Code

If you want to contribute code, please feel free to fork the repository and submit a Pull Request.

### Code Style

To maintain code quality and consistency, please adhere to the following style guidelines. These are enforced to prevent common linter warnings.

-   **Avoid `withOpacity`**: The `withOpacity` method on `Color` is deprecated and can lead to precision loss. Always use `withAlpha()` instead.
    
    ```dart
    // Incorrect
    myColor.withOpacity(0.5);
    
    // Correct
    myColor.withAlpha(128); // Alpha is an integer from 0 to 255
    ```

-   **Use Expression Bodies**: For functions or methods that contain only a single return statement, use an expression body (`=>`) instead of a block body (`{ ... }`).
    
    ```dart
    // Incorrect
    String sayHello() {
      return 'Hello!';
    }
    
    // Correct
    String sayHello() => 'Hello!';
    ```
