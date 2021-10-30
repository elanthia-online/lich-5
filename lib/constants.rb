LICH_DIR    ||= File.dirname(File.expand_path($PROGRAM_NAME))
TEMP_DIR    ||= "#{LICH_DIR}/temp".freeze
DATA_DIR    ||= "#{LICH_DIR}/data".freeze
SCRIPT_DIR  ||= "#{LICH_DIR}/scripts".freeze
LIB_DIR     ||= "#{LICH_DIR}/lib".freeze
MAP_DIR     ||= "#{LICH_DIR}/maps".freeze
LOG_DIR     ||= "#{LICH_DIR}/logs".freeze
BACKUP_DIR  ||= "#{LICH_DIR}/backup".freeze

TESTING = false

# add this so that require statements can take the form 'lib/file'

$LOAD_PATH << "#{LICH_DIR}"

# deprecated
$lich_dir = "#{LICH_DIR}/"
$temp_dir = "#{TEMP_DIR}/"
$script_dir = "#{SCRIPT_DIR}/"
$data_dir = "#{DATA_DIR}/"
