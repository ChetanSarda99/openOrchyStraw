# DataProcessor v1.0

A simple data processing library.

## Installation

```bash
pip install dataprocessor==1.0.0
```

## Requirements

- Python 3.6+
- pandas 0.25
- numpy 1.18

## Usage

```python
from dataprocessor import process_csv

# Load and process a CSV file
result = process_csv("data.csv", delimiter=",")
print(result.summary())
```

## API Reference

### `process_csv(filepath, delimiter=",")`

Loads a CSV file and returns a DataResult object.

**Parameters:**
- `filepath` (str): Path to CSV file
- `delimiter` (str): Column delimiter (default: ",")

**Returns:** DataResult

### `DataResult.summary()`

Returns a summary string of the processed data.

## Configuration

Set the `DATAPROCESSOR_CONFIG` environment variable to point to your config file:

```bash
export DATAPROCESSOR_CONFIG=/path/to/config.ini
```

## Contributing

1. Fork the repo
2. Create a branch
3. Submit a PR

## License

MIT License - Copyright 2021 DataProcessor Team
