# Package initialization hook
.onAttach <- function(libname, pkgname) {
  # Initialize logger
  init_logger()

  # Register task callback
  register_callback()

  # Display startup message
  log_file <- .pkg$log_file
  session_id <- substr(.pkg$session_id, 1, 8)

  packageStartupMessage(
    "rlogger: Command logging active\n",
    "  Log file: ", log_file, "\n",
    "  Session ID: ", session_id, "...\n",
    "  Mode: Immediate flush (every command logged instantly)\n",
    "  Use get_log_file() to see log path, disable_logging() to stop"
  )

  invisible(NULL)
}

# Package cleanup hook
.onUnload <- function(libpath) {
  # Deregister callback (no buffer to flush)
  deregister_callback()

  invisible(NULL)
}
