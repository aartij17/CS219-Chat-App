require 'jwt'
require 'json'
require 'sinatra'
require 'eventmachine'
require 'securerandom'
require 'thin'


$conns = []
$current_event_count = 0
$current_index = 0
$token_exists = false
$conn_exists = false

# constants
ONE_HOUR = 60 * 60
MAX_EVENTS = 100

# Key: Token Value: {'username':"", 'password': ""}
# need not be with key - token. Just username:password is enough
TOKEN_USER_MAP = Hash.new

# Key: Token
# Value: {connection, lastActivity}
# Updated when a new stream connection is established
TOKEN_CONN_MAP = Hash.new

# Key: username of the user
# value: password
# gets updated when new user signs up
USERS = Hash.new

# key: message ID
# value: Index in the array
# gets updated when a new event is broadcast.
ID_INDEX_MAP = Hash.new

# key: Index in the array
# value: message ID
# gets updated when a new event is broadcast.
INDEX_ID_MAP = Hash.new

# list of all the events(JOIN, ServerStatus for instance) and their details.
# new items are added to it when an event is broadcast
$events = []

#for jwt encode decode
AUTH_SECRET = "QXNoIG5hemcgdGhyYWthdHVsw7trIGFnaCBidXJ6dW0taXNoaSBrcmltcGF0dWw"

def update_id_index_map(msgId, curr_index)
  if !INDEX_ID_MAP[curr_index]
    INDEX_ID_MAP[curr_index] = msgId
  else
    ID_INDEX_MAP.delete(INDEX_ID_MAP[curr_index])
    INDEX_ID_MAP[curr_index] = msgId
  end
  ID_INDEX_MAP[msgId] = curr_index
end

def generate_token(username, password)
    begin
        payload = {
            "data": {
                :username => username,
                :password => password
            }.to_json
        }
        return JWT.encode payload, AUTH_SECRET, 'HS256'
    rescue Exception => e
        p "Exception in creating token", e.message
    end
end

def generate_error_message(message)
    {
        :message => message
    }.to_json
end

class Chat < Sinatra::Base
    configure do
        enable :cross_origin
    end

    before do
        response.headers['Access-Control-Allow-Origin'] = '*'
    end

    options "*" do
        response.headers["Allow"] = "GET, PUT, POST, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Authorization,
            Content-Type, Accept, X-User-Email, X-Auth-Token"
        response.headers["Access-Control-Allow-Origin"] = "*"
        200
    end

    def send_all_events(out)
        for index in (0...$events.length)
            out << "event: #{$events[(index + ($current_index)) % $events.length][:event]}\n"
            out << "data: #{$events[(index + ($current_index)) % $events.length][:data]}\n"
            out << "id: #{$events[(index + ($current_index)) % $events.length][:id]}\n\n"
        end
    end

    def send_last_n_events(out, last_event_id)
      if $events.length == $current_index
        for index in ((last_event_id+1)...$events.length)
          out << "event: #{$events[index][:event]}\n"
          out << "data: #{$events[index][:data]}\n"
          out << "id: #{$events[index][:id]}\n\n"
        end
      else
        for index in (0...$events.length)
            if (last_event_id + index + 1) % $events.length != $current_index
                out << "event: #{$events[(index + last_event_id + 1) % $events.length][:event]}\n"
                out << "data: #{$events[(index + last_event_id + 1) % $events.length][:data]}\n"
                out << "id: #{$events[(index + last_event_id + 1) % $events.length][:id]}\n\n"
            end
        end
      end
    end

    def broadcast_online_users(out)
        resp = {
            # :users => (USERS.keys.to_set).to_a
            :users => TOKEN_CONN_MAP.keys.map { |e| 
              TOKEN_USER_MAP[e][:username]
             }
        }
        event_obj = {
            :event => "Users",
            :data => resp.to_json,
            :id => SecureRandom.uuid.to_str
        }
        out << "event: #{event_obj[:event]}\n"
        out << "data: #{event_obj[:data]}\n"
        out << "id: #{event_obj[:id]}\n\n"
    end

    def broadcast_part_message(event_obj)
        $conns.each do |out|
            out << "event: #{event_obj[:event]}\n"
            out << "data: #{event_obj[:data]}\n"
            out << "id: #{event_obj[:id]}\n\n"
        end
    end

    options '/login' do
        headers["Access-Control-Allow-Origin"] = "*"
        status 200
    end

    post '/login' do
        # One of the checks put in on the reference chat is the presence of form fields
        # other than username and password.
        # TODO: Add checks for extraneous form fields. In their presence, return 422
        begin
            p "login"
            username = params["username"]
            password = params["password"]
            return [422, generate_error_message("Invalid username or password")] if !username or !password
            return [422, generate_error_message("Invalid username or password")] if username == "" or password == ""

            # check if user already signed up
            if !USERS[username]
                USERS[username] = password
            else
                return [403, generate_error_message("Invalid username or password")] unless USERS[username].eql?(password)
            end
            token = generate_token(username, password)
            out = TOKEN_CONN_MAP[token]
            if out
                $token_exists = true
                resp = {
                    :created => Time.now.to_f
                }
                event_obj = {
                    :event => "Disconnect",
                    :data => resp.to_json,
                    :id => SecureRandom.uuid.to_str
                }
                out << "event: #{event_obj[:event]}\n"
                out << "data: #{event_obj[:data]}\n"
                out << "id: #{event_obj[:id]}\n\n"
            else
                TOKEN_USER_MAP[token] = {
                    "username": username,
                    "password": password
                }
           end
            status 201
            {:token => token}.to_json
        rescue Exception => e
            p "exception in login post", e.message
            [500, generate_error_message(e.message)]
        end
    end

    options '/message' do
        headers["Access-Control-Allow-Origin"] = "*"
        status 200
    end

    post '/message' do
        begin
            auth_header = request.env["HTTP_AUTHORIZATION"]
            # existence of token needs to be checked.
            # if the token is already generated, user is logged in.
            return [403, generate_error_message("invalid header")] if !auth_header or !auth_header.include?("Bearer ")
            token = auth_header.split("Bearer ")[1]
            
            # check if the username to which the token belongs is part of the hash
            return [403, generate_error_message("invalid token")] if !TOKEN_USER_MAP[token]

            user = TOKEN_USER_MAP[token][:username]

            # fetch the message
            message = params['message']
            return [422, generate_error_message("invalid message")] if !message or message == ""
            resp = {
                :message => message,
                :user => user,
                :created => Time.now.to_f
            }
            event_obj = {
                :event => "Message",
                :data => resp.to_json,
                :id => SecureRandom.uuid.to_str
            }
            $conns.each do |out|
                out << "event: #{event_obj[:event]}\n"
                out << "data: #{event_obj[:data]}\n"
                out << "id: #{event_obj[:id]}\n\n"
            end
            $events[$current_index] = event_obj
            update_id_index_map(event_obj[:id], $current_index)
            $current_index = ($current_index + 1) % MAX_EVENTS
            $current_event_count += 1

            headers["Access-Control-Allow-Origin"] = "*"
            status 201
        rescue Exception => e
            p "Exception in POST message: ", e.message
            [500, generate_error_message(e.message)]
        end
    end

    options '/stream/:token' do
        headers["Access-Control-Allow-Origin"] = "*"
        status 200
    end

    get '/stream/:token' do
        begin
            last_event_id = request.env['HTTP_LAST_EVENT_ID']
            content_type 'text/event-stream'
            if !params["token"]
                return [403, generate_error_message("invalid token")]
            else
                if TOKEN_USER_MAP[params["token"]] == nil
                    return [403, generate_error_message("invalid token")]
                end
            end
            stream :keep_open do |out|
                $conns << out
                EventMachine::PeriodicTimer.new(1) {
                    out << "data: \0\n\n"
                }
                username = TOKEN_USER_MAP[params["token"]][:username]
                if !TOKEN_CONN_MAP[params['token']]
                  p "#{username} joins"
                  resp = {
                    :user => username,
                    :created => Time.now.to_f
                  }
                  event_obj = {
                      :event => "Join",
                      :data => resp.to_json,
                      :id => SecureRandom.uuid.to_str
                  }
                  $events[$current_index] = event_obj
                  update_id_index_map(event_obj[:id], $current_index)
                  $current_index = ($current_index + 1) % MAX_EVENTS
                  $current_event_count += 1
                  $conns.each do |conn|
                    if conn != out
                      conn << "event: #{event_obj[:event]}\n"
                      conn << "data: #{event_obj[:data]}\n"
                      conn << "id: #{event_obj[:id]}\n\n"
                    end
                  end
                else
                  p "#{username} joins after Disconnect"
                  $conn_exists = true
                  old_conn = TOKEN_CONN_MAP[params['token']]
                  resp = {
                    :created => Time.now.to_f
                  }
                  event_obj = {
                      :event => "Disconnect",
                      :data => resp.to_json,
                      :id => SecureRandom.uuid.to_str
                  }
                  old_conn << "event: #{event_obj[:event]}\n"
                  old_conn << "data: #{event_obj[:data]}\n"
                  old_conn << "id: #{event_obj[:id]}\n\n"
                  TOKEN_CONN_MAP.delete(params['token'])
                  $conns.delete(old_conn)
                end
                TOKEN_CONN_MAP[params['token']] = out
                broadcast_online_users(out)
                
                # if the last event id is sent to the server, stream all the events from that id onwards
                if last_event_id
                    p "Last event ID found: #{last_event_id}"
                    eventid_index = ID_INDEX_MAP[last_event_id]
                    if eventid_index
                      send_last_n_events(out, eventid_index)
                    else
                      p "Invalid event ID: #{last_event_id}"
                      send_all_events(out)
                    end
                else
                    send_all_events(out)
                end
                token = params["token"]
                out.callback {
                    unless ($token_exists || $conn_exists)
                      p "#{username} parts"
                        resp = {
                            :user => username,
                            :created => Time.now.to_f
                        }
                        event_obj = {
                            :event => "Part",
                            :data => resp.to_json,
                            :id => SecureRandom.uuid.to_str
                        }
                        broadcast_part_message(event_obj)
                        $events[$current_index] = event_obj
                        update_id_index_map(event_obj[:id], $current_index)
                        $current_index = ($current_index + 1) % MAX_EVENTS
                        $current_event_count += 1
                        TOKEN_USER_MAP.delete(token)
                        TOKEN_CONN_MAP.delete(token)
                        $conns.delete(out)
                    end
                    p "closing connection #{username}"
                    $token_exists = false
                    $conn_exists = false
                }
            end
        rescue Exception => e
            p "Exception in opening stream", e.message
            [500, generate_error_message(e.message)]
        end
    end
end

Thread.new {
    time_started = Time.now.to_i
    loop do
            current_time = Time.now.to_i
            elapsed_time = (current_time - time_started) / ONE_HOUR
        p "Server Status Thread Started #{elapsed_time.to_s} hours"
            resp = {
                :status => "Server uptime: #{elapsed_time.to_s} hours",
                :created => Time.now.to_f
            }
            event_obj = {
                :event => "ServerStatus",
                :data => resp.to_json,
                :id => SecureRandom.uuid.to_str
            }
            $events[$current_index] = event_obj
            update_id_index_map(event_obj[:id], $current_index)
            $current_index = ($current_index + 1) % MAX_EVENTS
            $current_event_count += 1
        $conns.each do |out|
            out << "event: #{event_obj[:event]}\n"
            out << "data: #{event_obj[:data]}\n"
            out << "id: #{event_obj[:id]}\n\n"
        end
        sleep(ONE_HOUR)
    end
}
