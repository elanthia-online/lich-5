# frozen_string_literal: true

# :streams routes Lich::Messaging.stream_window output through pushStream.
# Genie4 and Genie5 both map familiar, thoughts and combat to their own
# windows. Genie4 has no window for `speech` and drops that stream (Genie5
# shows it in Main with an [id] prefix); this is accepted.
{
  id: :genie,
  capabilities: %i[xml streams mono]
}
