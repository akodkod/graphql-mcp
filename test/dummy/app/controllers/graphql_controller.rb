# frozen_string_literal: true

class GraphqlController < ActionController::API
  def execute
    result = DummySchema.execute(
      params[:query],
      variables: graphql_variables,
      operation_name: params[:operationName],
      context: { current_user: },
    )

    render json: result
  end

  private

  def current_user
    token = request.authorization.to_s.delete_prefix("Bearer ").presence
    token && User.find_by(token:)
  end

  def graphql_variables
    variables = params[:variables]

    case variables
    when ActionController::Parameters then variables.to_unsafe_h
    when String then variables.present? ? JSON.parse(variables) : {}
    else {}
    end
  end
end
