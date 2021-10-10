class Request
  def self.request_body_read(request)
    request.body.read
  end

  def self.judge_bad_request(request, body, client)
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request

    end
  end
end
