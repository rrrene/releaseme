#!/usr/bin/env ruby

require 'optparse'

options = {}
OptionParser.new do |opts|
    opts.banner = "Usage: tarme.rb [options] PROJECT_NAME"

    opts.on("--origin trunk|stable", [:trunk, :stable],
            "Origin.",
            "   Used to deduce release branch and localization branches.") do |v|
        options[:origin] = v
    end

    opts.on("--version VERSION",
            "Version.",
            "   Versions should be kept in purely numerical format (e.g. x.x.x).",
            "   Alphanumerical version should be avoided if at all possible (e.g. x.x.xbeta1).") do |v|
        options[:version] = v
    end
end.parse!

if options[:origin].nil? or options[:version].nil? or ARGV.empty?
    puts "error, you need to set origin and version"
    exit 1
end

project_name = ARGV.pop

p options
p ARGV
p project_name


require_relative 'lib/project'
require_relative 'lib/kdegitrelease'
require_relative 'lib/kdel10n'
require_relative 'lib/documentation'


require_relative 'lib/projectsfile'

# TODO: move this somewhere
def find_element_from_xpath(xpath, element_identifier = nil)
    elements = ProjectsFile.instance.xml_doc.root.get_elements(xpath)
    unless element_identifier.nil? or element_identifier.empty?
        elements.each do | element |
            if (element_identifier == element.attribute('identifier').to_s)
                return element
            end
        end
    else
        return elements
    end
    return nil
end

# TODO: move this somewhere
def flat_project_resolver(project_id)
    doc = ProjectsFile.instance.xml_doc

    release_projects = Array.new
    if project_id.include?('/')
        # Wildcard release -> resolve by hand
        parts = project_id.split('/')
        if (parts.size < 2)
            puts "When using a wildcard project expression you must define component and module like component/module."
            puts "Whether you append anything after the"
            exit 1
        end
        component_element = find_element_from_xpath('/kdeprojects/component', parts.shift)
        module_element = find_element_from_xpath("#{component_element.xpath}/module", parts.shift)
        project_elements = find_element_from_xpath("#{module_element.xpath}/project")
        project_elements.each do | project_element |
            # FIXME: we really should construct from elements here, otherwise project resolves again....
            p = Project.new(project_element.attribute('identifier').to_s)
            p.resolve!
            release_projects << p
        end
    else
        # Project release -> resolve through REXML query to project level
        project_element = find_element_from_xpath('/kdeprojects/component/module/project', project.id)
        # FIXME: code copy from above, something is astray with the code layout ololol
        p = Project.new(project_element.attribute('identifier').to_s)
        p.resolve!
        release_projects << p
    end
    return release_projects
end

release_projects = flat_project_resolver(project_name)
p release_projects

release_data_file = File.open("release_data", "w")
release_projects.each do | project |
    project_name = project.id
    release = KdeGitRelease.new()
    release.vcs.repository = project.vcs.repository
    release.vcs.branch = project.i18n_trunk if options[:origin] == :trunk
    release.vcs.branch = project.i18n_stable if options[:origin] == :stable
    release.source.target = "#{project_name}-#{options[:version]}"
    release.get()

    # FIXME: why not pass project itself? Oo
    # FIXME: origin should be validated? technically optparse enforces proper values
    l10n = KdeL10n.new(options[:origin], project.component, project.module)
    l10n.get(release.source.target)

    doc = DocumentationL10n.new(options[:origin], project.component, project.module)
    doc.get(release.source.target)

    release.archive()

    branch = release.vcs.branch
    hash = release.vcs.hash
    tar = release.archive_.filename
    md5 = %x[md5sum #{tar}].split(' ')[0] unless tar.nil?
    release_data_file.write("#{branch};#{hash};#{tar};#{md5}\n")
end
