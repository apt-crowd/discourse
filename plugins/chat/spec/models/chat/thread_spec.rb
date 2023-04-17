# frozen_string_literal: true

RSpec.describe Chat::Thread do
  describe ".ensure_consistency!" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_3) { Fabricate(:chat_thread, channel: channel) }

    before do
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_1)

      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)
      Fabricate(:chat_message, chat_channel: channel, thread: thread_2)

      Fabricate(:chat_message, chat_channel: channel, thread: thread_3)
    end

    describe "updating replies_count for all threads" do
      it "counts correctly and does not include the original message" do
        described_class.ensure_consistency!
        expect(thread_1.reload.replies_count).to eq(3)
        expect(thread_2.reload.replies_count).to eq(4)
        expect(thread_3.reload.replies_count).to eq(1)
      end

      it "does not count deleted messages" do
        thread_1.chat_messages.last.trash!
        described_class.ensure_consistency!
        expect(thread_1.reload.replies_count).to eq(2)
      end

      it "sets the replies count to 0 if all the messages but the original message are deleted" do
        thread_1.replies.delete_all

        described_class.ensure_consistency!
        expect(thread_1.reload.replies_count).to eq(0)
      end
    end
  end

  describe ".grouped_messages" do
    fab!(:channel) { Fabricate(:category_channel) }
    fab!(:thread_1) { Fabricate(:chat_thread, channel: channel) }
    fab!(:thread_2) { Fabricate(:chat_thread, channel: channel) }

    fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel, thread: thread_1) }
    fab!(:message_3) { Fabricate(:chat_message, chat_channel: channel, thread: thread_2) }

    let(:result) { Chat::Thread.grouped_messages(**params) }

    context "when thread_ids provided" do
      let(:params) { { thread_ids: [thread_1.id, thread_2.id] } }

      it "groups all the message ids in each thread by thread ID" do
        expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
          {
            thread_message_ids: [thread_1.original_message_id, message_1.id, message_2.id],
            thread_id: thread_1.id,
            original_message_id: thread_1.original_message_id,
          },
        )
        expect(result.find { |res| res.thread_id == thread_2.id }.to_h).to eq(
          {
            thread_message_ids: [thread_2.original_message_id, message_3.id],
            thread_id: thread_2.id,
            original_message_id: thread_2.original_message_id,
          },
        )
      end

      context "when include_original_message is false" do
        let(:params) { { thread_ids: [thread_1.id, thread_2.id], include_original_message: false } }

        it "does not include the original message in the thread_message_ids" do
          expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
            {
              thread_message_ids: [message_1.id, message_2.id],
              thread_id: thread_1.id,
              original_message_id: thread_1.original_message_id,
            },
          )
        end
      end
    end

    context "when message_ids provided" do
      let(:params) do
        {
          message_ids: [
            thread_1.original_message_id,
            thread_2.original_message_id,
            message_1.id,
            message_2.id,
            message_3.id,
          ],
        }
      end

      it "groups all the message ids in each thread by thread ID" do
        expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
          {
            thread_message_ids: [thread_1.original_message_id, message_1.id, message_2.id],
            thread_id: thread_1.id,
            original_message_id: thread_1.original_message_id,
          },
        )
        expect(result.find { |res| res.thread_id == thread_2.id }.to_h).to eq(
          {
            thread_message_ids: [thread_2.original_message_id, message_3.id],
            thread_id: thread_2.id,
            original_message_id: thread_2.original_message_id,
          },
        )
      end

      context "when include_original_message is false" do
        let(:params) do
          {
            message_ids: [
              thread_1.original_message_id,
              thread_2.original_message_id,
              message_1.id,
              message_2.id,
              message_3.id,
            ],
            include_original_message: false,
          }
        end

        it "does not include the original message in the thread_message_ids" do
          expect(result.find { |res| res.thread_id == thread_1.id }.to_h).to eq(
            {
              thread_message_ids: [message_1.id, message_2.id],
              thread_id: thread_1.id,
              original_message_id: thread_1.original_message_id,
            },
          )
        end
      end
    end
  end
end
