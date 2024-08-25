# This file is a part of Redmine Checklists (redmine_checklists) plugin,
# issue checklists management plugin for Redmine
#
# Copyright (C) 2011-2022 RedmineUP
# http://www.redmineup.com/
#
# redmine_checklists is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# redmine_checklists is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with redmine_checklists.  If not, see <http://www.gnu.org/licenses/>.

class ChecklistsController < ApplicationController
  unloadable

  before_action :find_checklist_item, except: %i[index create]
  before_action :find_issue_by_id, only: %i[index create]
  before_action :authorize, except: [:done]
  helper :issues
  protect_from_forgery with: :null_session

  accept_api_auth :index, :update, :destroy, :create, :show

  def index
    @checklists = @issue.checklists
    respond_to do |format|
      format.api
    end
  end

  def show
    respond_to do |format|
      format.api
    end
  end

  def destroy
    @checklist_item.destroy
    respond_to do |format|
      format.api { render_api_ok }
    end
  end

  def create
    @checklist_item = Checklist.new
    @checklist_item.safe_attributes = params[:checklist]
    @checklist_item.issue = @issue
    respond_to do |format|
      format.api do
        if @checklist_item.save
          recalculate_issue_ratio(@checklist_item)
          render action: 'show', status: :created, location: checklist_url(@checklist_item)
        else
          render_validation_errors(@checklist_item)
        end
      end
    end
  end

  def update
    @checklist_item.safe_attributes = params[:checklist]
    respond_to do |format|
      format.api do
        if with_issue_journal { @checklist_item.save }
          recalculate_issue_ratio(@checklist_item)
          render_api_ok
        else
          render_validation_errors(@checklist_item)
        end
      end
    end
  end

  def done
    unless User.current.allowed_to?(:done_checklists, @checklist_item.issue.project)
      (render_403
       return false)
    end

    with_issue_journal do
      @checklist_item.is_done = params[:is_done] == 'true'
      if @checklist_item.save
        recalculate_issue_ratio(@checklist_item)
        true
      end
    end
    respond_to do |format|
      format.js
      format.html { redirect_to :back }
    end
  end

  private

  def find_issue_by_id
    @issue = Issue.find(params[:issue_id])
    @project = @issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_checklist_item
    @checklist_item = Checklist.find(params[:id])
    @project = @checklist_item.issue.project
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def with_issue_journal
    return unless yield

    true
  end

  def recalculate_issue_ratio(checklist_item)
    return unless (Setting.issue_done_ratio == 'issue_field') && RedmineChecklists.issue_done_ratio?

    Checklist.recalc_issue_done_ratio(checklist_item.issue.id)
    checklist_item.issue.reload
  end
end
