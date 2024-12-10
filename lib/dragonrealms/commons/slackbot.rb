class SlackBot
  def initialize
    @api_url = 'https://slack.com/api/'
    @lnet = (Script.running + Script.hidden).find { |val| val.name == 'lnet' }
    find_token unless authed?(UserVars.slack_token)

    params = { 'token' => UserVars.slack_token }
    res = post('users.list', params)
    @users_list = JSON.parse(res.body)
  end

  def authed?(token)
    params = { 'token' => token }
    res = post('auth.test', params)
    body = JSON.parse(res.body)
    body['ok']
  end

  def request_token(lichbot)
    ttl = 10
    send_time = Time.now
    @lnet.unique_buffer.push("chat to #{lichbot} RequestSlackToken")
    loop do
      line = get
      pause 0.05
      return false if Time.now - send_time > ttl

      case line
      when /\[Private\]-.*:#{lichbot}: "slack_token: (.*)"/
        msg = Regexp.last_match(1)
        return msg != 'Not Found' ? msg : false
      when /\[server\]: "no user .*/
        return false
      end
    end
  end

  def find_token
    lichbots = %w[Quilsilgas]
    echo 'Looking for a token...'
    return if lichbots.any? do |bot|
      token = request_token(bot)
      authed = authed?(token) if token
      UserVars.slack_token = token if authed
      authed
    end

    echo 'Unable to locate a token :['
    exit
  end

  def post(method, params)
    uri = URI.parse("#{@api_url}#{method}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Post.new(uri.path)
    req.set_form_data(params)
    http.request(req)
  end

  def direct_message(username, message)
    dm_channel = get_dm_channel(username)

    params = { 'token' => UserVars.slack_token, 'channel' => dm_channel, 'text' => "#{checkname}: #{message}", 'as_user' => true }
    post('chat.postMessage', params)
  end

  def get_dm_channel(username)
    user = @users_list['members'].find { |u| u['name'] == username }
    user['id']
  end
end
