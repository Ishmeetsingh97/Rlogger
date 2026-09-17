# Package environment to store state
.pkg <- new.env(parent = emptyenv())

# Initialize the logging system
init_logger <- function() {
  # Generate unique session ID
  .pkg$session_id <- uuid::UUIDgenerate()

  # Get log path from environment variable
  .pkg$log_path <- Sys.getenv("RLOGGER_PATH", unset = "~/r_logs")
  .pkg$log_path <- path.expand(.pkg$log_path)

  # Create log directory if it doesn't exist
  if (!dir.exists(.pkg$log_path)) {
    dir.create(.pkg$log_path, recursive = TRUE, showWarnings = FALSE)
  }

  # Initialize state (no buffer - immediate flush)
  .pkg$command_count <- 0
  .pkg$callback_id <- NULL

  # Get user and computer info
  user <- as.character(Sys.info()["user"])
  computer <- as.character(Sys.info()["nodename"])

  # Create session-specific log file path with user and computer
  session_start <- format(Sys.time(), "%Y%m%d_%H%M%S")
  session_id_short <- substr(.pkg$session_id, 1, 8)

  # Filename format: {computer}_{user}_{timestamp}_{sessionid}.jsonl
  .pkg$log_file <- file.path(.pkg$log_path,
                             paste0(computer, "_", user, "_", session_start, "_", session_id_short, ".jsonl"))

  invisible(NULL)
}

# Register task callback
register_callback <- function() {
  if (is.null(.pkg$callback_id)) {
    .pkg$callback_id <- addTaskCallback(logger_callback, name = "rlogger")
  }
  invisible(NULL)
}

# Deregister task callback
deregister_callback <- function() {
  if (!is.null(.pkg$callback_id)) {
    removeTaskCallback("rlogger")
    .pkg$callback_id <- NULL
  }
  invisible(NULL)
}

# Main task callback function
logger_callback <- function(expr, value, ok, visible) {
  tryCatch({
    # Increment command counter
    .pkg$command_count <- .pkg$command_count + 1

    # Deparse the command
    cmd_text <- paste(deparse(expr, width.cutoff = 500L), collapse = "\n")

    # Collect metadata
    metadata <- list(
      timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3", tz = "UTC"),
      session_id = .pkg$session_id,
      user = as.character(Sys.info()["user"]),
      computer = as.character(Sys.info()["nodename"]),
      command = cmd_text,
      command_number = .pkg$command_count,
      success = ok
    )

    # Immediate flush - write every command right away
    write_log_entry(metadata)

  }, error = function(e) {
    # Silent failure - don't break user's R session
    # Could optionally log errors to a separate file
  })

  # Return TRUE to keep callback registered
  return(TRUE)
}

# Write a single log entry immediately to file
write_log_entry <- function(metadata) {
  tryCatch({
    # Convert to JSON
    jsonl_line <- jsonlite::toJSON(metadata, auto_unbox = TRUE)

    # Append to session-specific log file
    conn <- file(.pkg$log_file, open = "a")
    on.exit(close(conn), add = TRUE)
    writeLines(jsonl_line, conn)

    # Force flush to disk
    flush(conn)

  }, error = function(e) {
    # Silent failure - don't break user's R session
  })

  invisible(NULL)
}

# Public function: manually flush logs (no-op now since we flush immediately)
flush_logs <- function() {
  message("rlogger: Logs are flushed immediately after every command")
  invisible(NULL)
}

# Public function: get session ID
get_session_id <- function() {
  .pkg$session_id
}

# Public function: get current log file path
get_log_file <- function() {
  .pkg$log_file
}
