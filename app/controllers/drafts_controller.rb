# frozen_string_literal: true

class DraftsController < ApplicationController
  requires_login

  skip_before_action :check_xhr, :preload_json

  def index
    params.permit(:offset)
    params.permit(:limit)

    stream = Draft.stream(user: current_user, offset: params[:offset], limit: params[:limit])

    render json: { drafts: stream ? serialize_data(stream, DraftSerializer) : [] }
  end

  def show
    raise Discourse::NotFound.new if params[:id].blank?

    seq = params[:sequence] || DraftSequence.current(current_user, params[:id])
    render json: { draft: Draft.get(current_user, params[:id], seq), draft_sequence: seq }
  end

  def create
    raise Discourse::NotFound.new if params[:draft_key].blank?

    if params[:data].size > SiteSetting.max_draft_length
      raise Discourse::InvalidParameters.new(:data)
    end

    begin
      data = JSON.parse(params[:data])
    rescue JSON::ParserError
      raise Discourse::InvalidParameters.new(:data)
    end

    sequence =
      begin
        Draft.set(
          current_user,
          params[:draft_key],
          params[:sequence].to_i,
          params[:data],
          params[:owner],
          force_save: params[:force_save],
        )
      rescue Draft::OutOfSequence
        begin
          if !Draft.exists?(user_id: current_user.id, draft_key: params[:draft_key])
            Draft.set(
              current_user,
              params[:draft_key],
              DraftSequence.current(current_user, params[:draft_key]),
              params[:data],
              params[:owner],
            )
          else
            raise Draft::OutOfSequence
          end
        rescue Draft::OutOfSequence
          render_json_error I18n.t("draft.sequence_conflict_error.title"),
                            status: 409,
                            extras: {
                              description: I18n.t("draft.sequence_conflict_error.description"),
                            }
          return
        end
      end

    json = success_json.merge(draft_sequence: sequence)

    if data.present?
      # this is a bit of a kludge we need to remove (all the parsing) too many special cases here
      # we need to catch action edit and action editSharedDraft
      if data["postId"].present? && data["originalText"].present? &&
           data["action"].to_s.start_with?("edit")
        post = Post.find_by(id: data["postId"])
        if post && post.raw != data["originalText"]
          conflict_user = BasicUserSerializer.new(post.last_editor, root: false)
          render json: json.merge(conflict_user: conflict_user)
          return
        end
      end
    end

    render json: json
  end

  def destroy
    user =
      if is_api?
        if @guardian.is_admin?
          fetch_user_from_params
        else
          raise Discourse::InvalidAccess
        end
      else
        current_user
      end

    begin
      Draft.clear(user, params[:id], params[:sequence].to_i)
    rescue Draft::OutOfSequence => e
      return render json: failed_json.merge(errors: e), status: 404
    rescue StandardError => e
      return render json: failed_json.merge(errors: e), status: 401
    end

    render json: success_json
  end
end
