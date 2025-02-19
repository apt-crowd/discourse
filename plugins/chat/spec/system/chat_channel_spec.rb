# frozen_string_literal: true

RSpec.describe "Chat channel", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when sending a message" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    context "with lots of messages" do
      before { 50.times { Fabricate(:chat_message, chat_channel: channel_1) } }

      it "loads most recent messages" do
        unloaded_message = Fabricate(:chat_message, chat_channel: channel_1)
        visit("/chat/c/-/#{channel_1.id}/#{message_1.id}")

        expect(channel).to have_no_loading_skeleton
        expect(page).to have_no_css("[data-id='#{unloaded_message.id}']")

        channel.send_message("test_message")

        expect(channel).to have_no_loading_skeleton
        expect(page).to have_css("[data-id='#{unloaded_message.id}']")
      end
    end

    context "with two sessions opened on same channel" do
      it "syncs the messages" do
        using_session(:tab_1) do
          sign_in(current_user)
          chat.visit_channel(channel_1)
        end

        using_session(:tab_2) do
          sign_in(current_user)
          chat.visit_channel(channel_1)
        end

        using_session(:tab_1) { channel.send_message("test_message") }

        using_session(:tab_2) { expect(channel).to have_message(text: "test_message") }
      end
    end

    it "allows to edit this message once persisted" do
      chat.visit_channel(channel_1)
      channel.send_message("aaaaaaaaaaaaaaaaaaaa")
      expect(page).to have_no_css(".chat-message-staged")
      last_message = find(".chat-message-container:last-child")
      last_message.hover

      expect(page).to have_css(
        ".chat-message-actions-container[data-id='#{last_message["data-id"]}']",
      )
    end
  end

  context "when clicking the arrow button" do
    before do
      channel_1.add(current_user)
      50.times { Fabricate(:chat_message, chat_channel: channel_1) }
      sign_in(current_user)
    end

    it "jumps to the bottom of the channel" do
      unloaded_message = Fabricate(:chat_message, chat_channel: channel_1)
      visit("/chat/message/#{message_1.id}")

      expect(channel).to have_no_loading_skeleton
      expect(page).to have_no_css("[data-id='#{unloaded_message.id}']")

      find(".chat-scroll-to-bottom").click

      expect(channel).to have_no_loading_skeleton
      expect(page).to have_css("[data-id='#{unloaded_message.id}']")
    end
  end

  context "when returning to a channel where last read is not last message" do
    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "jumps to the bottom of the channel" do
      channel_1.membership_for(current_user).update!(last_read_message: message_1)
      messages = 50.times.map { Fabricate(:chat_message, chat_channel: channel_1) }
      chat.visit_channel(channel_1)

      expect(page).to have_css("[data-id='#{messages.first.id}']")
      expect(page).to have_no_css("[data-id='#{messages.last.id}']")
    end
  end

  context "when a new message is created" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      channel_1.add(other_user)
      channel_1.add(current_user)
      50.times { Fabricate(:chat_message, chat_channel: channel_1) }
      sign_in(current_user)
    end

    it "doesn’t scroll the pane" do
      visit("/chat/message/#{message_1.id}")

      new_message =
        Chat::MessageCreator.create(
          chat_channel: channel_1,
          user: other_user,
          content: "this is fine",
        ).chat_message

      expect(page).to have_no_content(new_message.message)
    end
  end

  context "when a message contains mentions" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      channel_1.add(other_user)
      channel_1.add(current_user)
      Fabricate(
        :chat_message,
        chat_channel: channel_1,
        message: "hello @here @all @#{current_user.username} @#{other_user.username} @unexisting",
        user: other_user,
      )
      sign_in(current_user)
    end

    it "highlights the mentions" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector(".mention.highlighted.valid-mention", text: "@here")
      expect(page).to have_selector(".mention.highlighted.valid-mention", text: "@all")
      expect(page).to have_selector(
        ".mention.highlighted.valid-mention",
        text: "@#{current_user.username}",
      )
      expect(page).to have_selector(".mention", text: "@#{other_user.username}")
      expect(page).to have_selector(".mention", text: "@unexisting")
    end
  end

  context "when reply is right under" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      Fabricate(:chat_message, in_reply_to: message_1, user: other_user, chat_channel: channel_1)
      channel_1.add(other_user)
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "doesn’t show the reply-to line" do
      chat.visit_channel(channel_1)

      expect(page).to have_no_selector(".chat-reply__excerpt")
    end
  end

  context "when reply is not directly connected" do
    fab!(:other_user) { Fabricate(:user) }

    before do
      Fabricate(:chat_message, user: other_user, chat_channel: channel_1)
      Fabricate(:chat_message, in_reply_to: message_1, user: other_user, chat_channel: channel_1)
      channel_1.add(other_user)
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "shows the reply-to line" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector(".chat-reply__excerpt")
    end
  end

  context "when replying to message that has tags" do
    fab!(:other_user) { Fabricate(:user) }
    fab!(:message_2) do
      Fabricate(
        :chat_message,
        user: other_user,
        chat_channel: channel_1,
        message: "<mark>not marked</mark>",
      )
    end

    before do
      Fabricate(:chat_message, user: other_user, chat_channel: channel_1)
      Fabricate(:chat_message, in_reply_to: message_2, user: current_user, chat_channel: channel_1)
      channel_1.add(other_user)
      channel_1.add(current_user)
      sign_in(current_user)
    end

    xit "escapes the reply-to line" do
      chat.visit_channel(channel_1)

      expect(find(".chat-reply .chat-reply__excerpt")["innerHTML"].strip).to eq(
        "&lt;mark&gt;not marked&lt;/mark&gt;",
      )
    end
  end

  context "when messages are separated by a day" do
    before do
      Fabricate(:chat_message, chat_channel: channel_1, created_at: 2.days.ago)

      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "shows a date separator" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector(".chat-message-separator__text", text: "Today")
    end
  end

  context "when a message contains code fence" do
    fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1, message: <<~MESSAGE) }
      Here's a message with code highlighting

      \`\`\`ruby
      Widget.triangulate(arg: "test")
      \`\`\`
      MESSAGE

    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "adds the correct lang" do
      chat.visit_channel(channel_1)

      expect(page).to have_selector("code.lang-ruby")
    end
  end
end
