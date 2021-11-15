module Events::LeaveEvent
  def leave_events(group_id, count_menbers)
    return if count_menbers['count'].to_i > 1 # "おまじない"が使用された際は、clientからの返り値は'{}'で、存在しないキーに'.to_i'を行うと'0'を返します。

    line_group = LineGroup.find_by(line_group_id: group_id)
    line_group.destroy!
  end
end
