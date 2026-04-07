"""DataProcessor v3.2 — data processing library.

This is the ACTUAL current code. The README is outdated and doesn't match.
The agent should update the README to reflect the real API.
"""

import csv
import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional


@dataclass
class ProcessorConfig:
    """Configuration for the data processor."""
    max_rows: int = 10000
    encoding: str = "utf-8"
    strict_mode: bool = False
    output_format: str = "json"


@dataclass
class DataResult:
    """Result of processing a data file."""
    rows: list = field(default_factory=list)
    headers: list = field(default_factory=list)
    source_file: str = ""
    row_count: int = 0
    error_count: int = 0

    def summary(self) -> dict:
        """Return a summary dict (NOT a string as old docs say)."""
        return {
            "source": self.source_file,
            "headers": self.headers,
            "row_count": self.row_count,
            "error_count": self.error_count,
        }

    def to_json(self) -> str:
        """Export results as JSON string."""
        return json.dumps({
            "headers": self.headers,
            "rows": self.rows,
            "summary": self.summary(),
        }, indent=2)

    def to_csv(self, output_path: str) -> None:
        """Export results as CSV."""
        with open(output_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(self.headers)
            writer.writerows(self.rows)


def load_config(config_path: Optional[str] = None) -> ProcessorConfig:
    """Load config from JSON file (NOT .ini as old docs say).

    Reads from DATAPROCESSOR_CONFIG env var or explicit path.
    Config file format is JSON, not INI.
    """
    path = config_path or os.environ.get("DATAPROCESSOR_CONFIG")
    if path and Path(path).exists():
        with open(path) as f:
            data = json.load(f)
        return ProcessorConfig(**{k: v for k, v in data.items()
                                  if k in ProcessorConfig.__dataclass_fields__})
    return ProcessorConfig()


def process_file(filepath: str, *, delimiter: str = ",",
                 config: Optional[ProcessorConfig] = None,
                 file_format: str = "csv") -> DataResult:
    """Process a data file and return a DataResult.

    This replaces the old process_csv() function (which no longer exists).

    Parameters:
        filepath: Path to data file
        delimiter: Column delimiter for CSV files (default: ",")
        config: Optional ProcessorConfig (loads default if None)
        file_format: "csv" or "json" (default: "csv")

    Returns:
        DataResult with parsed data
    """
    if config is None:
        config = load_config()

    result = DataResult(source_file=filepath)

    if file_format == "csv":
        with open(filepath, encoding=config.encoding) as f:
            reader = csv.reader(f, delimiter=delimiter)
            result.headers = next(reader, [])
            for i, row in enumerate(reader):
                if i >= config.max_rows:
                    break
                if len(row) != len(result.headers):
                    result.error_count += 1
                    if config.strict_mode:
                        continue
                result.rows.append(row)
            result.row_count = len(result.rows)

    elif file_format == "json":
        with open(filepath, encoding=config.encoding) as f:
            data = json.load(f)
        if isinstance(data, list) and data:
            result.headers = list(data[0].keys()) if isinstance(data[0], dict) else []
            for i, item in enumerate(data):
                if i >= config.max_rows:
                    break
                if isinstance(item, dict):
                    result.rows.append([item.get(h, "") for h in result.headers])
                else:
                    result.rows.append([item])
            result.row_count = len(result.rows)

    return result
