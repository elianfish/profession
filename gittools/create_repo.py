#/usr/bin/env python
# -*- coding: utf-8 -*


"auto create git repo"

import os,sys
import gitlab

WORKDIR = os.path.split(os.path.realpath(__file__))[0]
PROJECTFILE = os.path.join(WORKDIR, 'project.list')
USER_HOME = os.environ.get('HOME')

def main():
    fp = open(PROJECTFILE, 'r')
    lines = fp.readlines()
    fp.close()

    ## login
    gl = gitlab.Gitlab.from_config('somewhere', ['{}/.python-gitlab.cfg'.format(USER_HOME)])

    for line in lines:
        line = line.strip('\n')
        repo_url = line.split(',')[0]
        descri = line.split(',')[1]
        user_name = line.split(',')[2]
        create_repo(repo_url, descri, user_name)

def create_repo(repo_url, descri, user_name):

    ## data
    parent_group_name = repo_url.split('/')[3]
    sub_group_name  = repo_url.split('/')[4]
    project_name = repo_url.split('/')[5].replace('.git','')
    print (parent_group_name,sub_group_name,project_name)
    descri = project_name

    ## login
    gl = gitlab.Gitlab.from_config('somewhere', ['{}/.python-gitlab.cfg'.format(USER_HOME)])

    user_id = gl.users.list(search=user_name)[0].id
    group = gl.groups.get(parent_group_name)  # 获取parent组对象

    ## 查找子组
    subgroup_id = group.subgroups.list(search=sub_group_name)
    if subgroup_id:
        print ("%s subgroup found: %s" % (sub_group_name, subgroup_id))
        subgroup_id_value = subgroup_id[0].id
        subgroup = gl.groups.get(subgroup_id_value)
    else:
        print ("%s subgroup not exist" % sub_group_name)
        sys.exit(0)   #子组不存在退出

    # 查找项目，不存在创建
    project = subgroup.projects.list(search=project_name)
    if project:
        print ("[INFO]%s project found: %s" % (project_name, project))
    else:
        print ("%s project not exist,create it" % project_name)
        new_project = gl.projects.create({'name': project_name, 'namespace_id': subgroup_id_value, 'description': descri}) # 创建项目
        member = new_project.members.create({'user_id': user_id, 'access_level':
                                         gitlab.MASTER_ACCESS})


if __name__ == '__main__':
    main()
