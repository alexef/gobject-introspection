/**
 * g_file_get_contents:
 * @contents: (out):
 * @length: (out) (allow-none):
 */

/**
 * g_file_set_contents:
 * @contents: (array length=length) (element-type guint8):
 */

/**
 * g_file_open_tmp:
 * @name_used: (out):
 */

/**
 * g_filename_to_uri:
 * @hostname: (allow-none):
 */

/**
 * g_build_pathv:
 * @separator:
 * @args: (array zero-terminated=1):
 * Return value:
 */

/**
 * g_build_filenamev:
 * @args: (array zero-terminated=1):
 * Return value:
 */

/**
 * g_markup_escape_text:
 * Return value: (transfer full):
 */

/**
 * g_thread_init:
 * @vtable: (allow-none):
 */

/**
 * g_main_loop_new:
 * @context: (allow-none):
 */

/**
 * g_idle_add_full:
 *
 * Rename to: g_idle_add
 */

/**
 * g_child_watch_add_full:
 *
 * Rename to: g_child_watch_add
 */

/**
 * g_io_add_watch_full:
 *
 * Rename to: g_io_add_watch
 */

/**
 * g_timeout_add_full:
 *
 * Rename to: g_timeout_add
 */

/**
 * g_timeout_add_seconds_full:
 *
 * Rename to: g_timeout_add_seconds
 */

/**
 * g_option_context_parse:
 * @argc: (inout):
 * @argv: (array length=argc) (inout) (allow-none):
 */

/**
 * GSourceFunc:
 * @data: (closure data):
 */

/**
 * GIOFunc:
 * @data: (closure data):
 */

/**
 * g_spawn_async:
 * @working_directory: (allow-none):
 * @argv: (array zero-terminated=1):
 * @envp: (array zero-terminated=1) (allow-none):
 * @child_setup: (scope async) (allow-none):
 * @user_data: (allow-none):
 * @child_pid: (out):
 */

/**
 * g_spawn_async_with_pipes:
 * @working_directory: (allow-none):
 * @argv: (array zero-terminated=1):
 * @envp: (array zero-terminated=1) (allow-none):
 * @child_setup: (scope async) (allow-none):
 * @user_data: (allow-none):
 * @child_pid: (out):
 * @standard_input: (out):
 * @standard_output: (out):
 * @standard_error: (out):
 */

/**
 * g_spawn_sync:
 * @working_directory: (allow-none):
 * @argv: (array zero-terminated=1):
 * @envp: (array zero-terminated=1) (allow-none):
 * @child_setup: (scope call) (allow-none):
 * @user_data: (allow-none):
 * @standard_output: (out):
 * @standard_error: (out):
 * @exit_status: (out):
 */

/**
 * g_spawn_command_line_sync:
 * @standard_output: (out):
 * @standard_error: (out):
 * @exit_status: (out):
 */

/**
 * g_get_system_config_dirs:
 * Return value: (array zero-terminated=1) (transfer none):
 */

/**
 * g_get_system_data_dirs:
 * Return value: (array zero-terminated=1) (transfer none):
 */

/**
 * g_shell_parse_argv:
 * @command_line:
 * @argcp: (out):
 * @argvp: (out) (array zero-terminated=1):
 * @error:
 */

/**
 * g_completion_complete_utf8:
 * Return value: (element-type utf8) (transfer none):
 */

/**
 * g_convert:
 * @bytes_read: (out):
 * @bytes_written: (out):
 */

/**
 * g_key_file_get_string:
 * Return value: (transfer full):
 */

/**
  * g_key_file_get_string_list:
  * @length: (out):
  * Return value: (array zero-terminated=1 length=length) (element-type utf8) (transfer full):
  */

/**
  * g_key_file_set_string_list:
  * @list: (array zero-terminated=1 length=length) (element-type utf8):
  * @length: (out):
  */

/**
 * g_key_file_get_locale_string:
 * @locale: (null-ok):
 * Return value: (transfer full):
 */

/**
  * g_key_file_get_locale_string_list:
  * @length: (out):
  * @locale: (null-ok):
  * Return value: (array zero-terminated=1 length=length) (element-type utf8) (transfer full):
  */

/**
  * g_key_file_set_locale_string_list:
  * @list: (array zero-terminated=1 length=length) (element-type utf8):
  * @length: (out):
  */

/**
  * GVariant: (foreign)
  *
  */

/**
 * g_variant_new_strv:
 * @strv: (array length=length) (element-type utf8):
 */

/**
 * g_variant_new_variant: (constructor)
 * @value:
 * @returns:
 */

/**
 * g_variant_get_strv:
 * @length: (allow-none):
 * @returns: (array length=length) (transfer container):
 */

/**
 * g_variant_get_string:
 * @length: (allow-none) (default NULL) (out):
 * @returns:
 */

/**
 * g_variant_builder_end:
 * @returns: (transfer none):
 */

/**
 * g_get_language_names:
 * @returns: (array zero-terminated=1) (transfer none):
 */

// Skip this as "tm" is not available at present.

/**
 * g_date_to_struct_tm: (skip)
 */

/**
 * g_get_environ:
 * @returns: (array zero-terminated=1) (transfer full):
 */

/**
 * g_listenv:
 * @returns: (array zero-terminated=1) (transfer full):
 */

/**
 * g_base64_encode:
 * @data: (array length=len) (element-type guint8):
 *
 * @returns: (transfer full):
 */

/**
 * g_base64_decode:
 * @text:
 * @out_len: (out):
 *
 * @returns: (array length=out_len) (element-type guint8) (transfer full):
 */
