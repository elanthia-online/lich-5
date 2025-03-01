LICH_DIR    ||= File.dirname(File.expand_path($PROGRAM_NAME))
TEMP_DIR    ||= File.join(LICH_DIR, "temp").freeze
DATA_DIR    ||= File.join(LICH_DIR, "data").freeze
SCRIPT_DIR  ||= File.join(LICH_DIR, "scripts").freeze
LIB_DIR     ||= File.join(LICH_DIR, "lib").freeze
MAP_DIR     ||= File.join(LICH_DIR, "maps").freeze
LOG_DIR     ||= File.join(LICH_DIR, "logs").freeze
BACKUP_DIR  ||= File.join(LICH_DIR, "backup").freeze

TESTING = false

# add this so that require statements can take the form 'lib/file'

$LOAD_PATH << "#{LICH_DIR}"

# deprecated
$lich_dir = "#{LICH_DIR}/"
$temp_dir = "#{TEMP_DIR}/"
$script_dir = "#{SCRIPT_DIR}/"
$data_dir = "#{DATA_DIR}/"

# transcoding migrated 2024-06-13
DIRMAP = {
  'out'  => 'K',
  'ne'   => 'B',
  'se'   => 'D',
  'sw'   => 'F',
  'nw'   => 'H',
  'up'   => 'I',
  'down' => 'J',
  'n'    => 'A',
  'e'    => 'C',
  's'    => 'E',
  'w'    => 'G',
}
SHORTDIR = {
  'out'       => 'out',
  'northeast' => 'ne',
  'southeast' => 'se',
  'southwest' => 'sw',
  'northwest' => 'nw',
  'up'        => 'up',
  'down'      => 'down',
  'north'     => 'n',
  'east'      => 'e',
  'south'     => 's',
  'west'      => 'w',
}
LONGDIR = {
  'out'  => 'out',
  'ne'   => 'northeast',
  'se'   => 'southeast',
  'sw'   => 'southwest',
  'nw'   => 'northwest',
  'up'   => 'up',
  'down' => 'down',
  'n'    => 'north',
  'e'    => 'east',
  's'    => 'south',
  'w'    => 'west',
}
MINDMAP = {
  'clear as a bell' => 'A',
  'fresh and clear' => 'B',
  'clear'           => 'C',
  'muddled'         => 'D',
  'becoming numbed' => 'E',
  'numbed'          => 'F',
  'must rest'       => 'G',
  'saturated'       => 'H',
}
ICONMAP = {
  'IconKNEELING'  => 'GH',
  'IconPRONE'     => 'G',
  'IconSITTING'   => 'H',
  'IconSTANDING'  => 'T',
  'IconSTUNNED'   => 'I',
  'IconHIDDEN'    => 'N',
  'IconINVISIBLE' => 'D',
  'IconDEAD'      => 'B',
  'IconWEBBED'    => 'C',
  'IconJOINED'    => 'P',
  'IconBLEEDING'  => 'O',
}
