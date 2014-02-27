# encoding: utf-8

require 'spec_helper'


module Cql
  describe Connection do
    describe '#initialize' do
      it 'does not connect' do
        described_class.new
      end
    end

    describe '#connect' do
      let :host do
        Socket.gethostname
      end

      let :port do
        34535
      end

      let :connection do
        described_class.new(host: host, port: port)
      end

      def start_server!
        @server_running = [true]
        @connects = []
        @sockets = [TCPServer.new(port)]
        @server_thread = Thread.start(@sockets, @server_running, @connects) do |sockets, server_running, connects|
          begin
            Thread.current.abort_on_exception = true
            while server_running[0]
              readables, _ = IO.select(sockets, nil, nil, 0)
              if readables
                readables.each do |socket|
                  connection, _ = socket.accept_nonblock
                  connects << 1
                  connection.close
                end
              end
            end
          end
        end
      end

      def stop_server!
        return unless @server_running[0]
        @server_running[0] = false
        @server_thread.join
        @sockets.each(&:close)
      end

      before do
        start_server!
      end

      after do
        connection.close unless connection.closed?
        stop_server!
      end

      it 'connects to the specified host and port' do
        connection.connect
        sleep 0.1
        stop_server!
        @connects.should have(1).items
      end

      it 'does nothing when called a second time' do
        connection.connect
        sleep 0.1
        connection.connect
        sleep 0.1
        stop_server!
        @connects.should have(1).items
      end

      it 'returns the connection' do
        connection.connect.should equal(connection)
      end

      it 'raises an error if it cannot connect' do
        expect { described_class.new(host: 'huffabuff.local', timeout: 1).connect }.to raise_error(ConnectionError)
        expect { described_class.new(port: 9999, timeout: 1).connect }.to raise_error(ConnectionError)
      end

      it 'times out quickly when it cannot connect' do
        started_at = Time.now
        begin
          described_class.new(port: 9999, timeout: 1).connect
        rescue ConnectionError
        end
        time_taken = (Time.now - started_at).to_f
        time_taken.should be < 1.5
      end
    end
  end
end