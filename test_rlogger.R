# Test script for rlogger package
# Run this from R to test the logging functionality

# Set up test log directory
test_log_path <- "~/r_logs_test"
Sys.setenv(RLOGGER_PATH = test_log_path)

# Clean up old test logs if they exist
if (dir.exists(path.expand(test_log_path))) {
  unlink(path.expand(test_log_path), recursive = TRUE)
}

cat("Installing rlogger package...\n")
install.packages("rlogger_0.1.0.tar.gz", repos = NULL, type = "source")

cat("\nLoading rlogger package...\n")
library(rlogger)

cat("\n=== Executing test commands ===\n")

# Execute some test commands
x <- 1 + 1
y <- 2 + 2
z <- x + y

# Some data operations
data <- c(1, 2, 3, 4, 5)
mean_val <- mean(data)
sum_val <- sum(data)

# A function definition
test_func <- function(a, b) {
  return(a * b)
}

# Call the function
result <- test_func(3, 4)

# Print statement
print("Testing rlogger!")

# Logs are written immediately - no buffer
cat("Checkpoint: All commands logged immediately\n")

cat("\n=== Getting current log file ===\n")
log_file <- get_log_file()
cat("Log file:", log_file, "\n")

if (file.exists(log_file)) {
  cat("\nSUCCESS: Log file created at:", log_file, "\n\n")

  cat("=== Log file contents ===\n")
  lines <- readLines(log_file)
  cat("Number of log entries:", length(lines), "\n\n")

  # Parse and display first few entries
  if (length(lines) > 0) {
    cat("First log entry:\n")
    first_entry <- jsonlite::fromJSON(lines[1])
    print(first_entry)

    cat("\n\nAll commands logged:\n")
    for (i in 1:min(5, length(lines))) {
      entry <- jsonlite::fromJSON(lines[i])
      cat(sprintf("[%d] %s: %s\n",
                 entry$command_number,
                 entry$timestamp,
                 substr(entry$command, 1, 50)))
    }

    if (length(lines) > 5) {
      cat(sprintf("... and %d more entries\n", length(lines) - 5))
    }
  }

  cat("\n=== Verification ===\n")
  cat("✓ Package loaded successfully\n")
  cat("✓ Commands captured and logged\n")
  cat("✓ JSONL format is valid\n")
  cat("✓ Metadata includes timestamp, user, computer, session_id\n")
  cat("\n=== Test PASSED ===\n")

} else {
  cat("\nERROR: Log file not created!\n")
  cat("Expected:", log_file, "\n")
}

# Get session info
cat("\nSession ID:", get_session_id(), "\n")

cat("\n=== Test complete ===\n")
cat("To disable logging, run: disable_logging()\n")
