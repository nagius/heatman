
class CustomFormatter < Logger::Formatter
    DateFormat = "%Y-%m-%d %H:%M:%S %z"

    def initialize(env)
        @env=env
    end

    def user_ip
        @env['HTTP_X_FORWARDED_FOR'] || @env["REMOTE_ADDR"] || "-"
    end

    def user_name
        @env['HTTP_X_REMOTE_USER'] || @env["REMOTE_USER"] || "-"
    end

    def call(severity, time, progname, msg)
        "#{user_ip} #{user_name} - [#{time.strftime(DateFormat)}] #{severity} #{msg2str(msg)}\n"
    end
end

# vim: ts=4:sw=4:ai:noet
