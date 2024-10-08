require "./base_parser"

module CoverageReporter
  # Simplecov coverage format parser.
  #
  # See: [https://github.com/simplecov-ruby/simplecov](https://github.com/simplecov-ruby/simplecov)
  class SimplecovParser < BaseParser
    alias Coverage = Array(Hits?)

    class ComplexCoverage
      include JSON::Serializable

      property lines : Coverage
      property branches : Hash(String, Hash(String, Hits)) | Nil
    end

    class Report
      include JSON::Serializable

      property coverage : Hash(String, Coverage | ComplexCoverage)
      property timestamp : Int64?
    end

    alias SimplecovReport = Hash(String, Report)

    def globs : Array(String)
      [
        ".resultset.json",
        "**/*/.resultset.json",
      ]
    end

    def matches?(filename : String) : Bool
      !filename.ends_with?(".gcov") &&
        !filename.ends_with?(".lcov") && !filename.ends_with?("lcov.info")
    end

    def parse(filename : String) : Array(FileReport)
      reports = [] of FileReport

      data = SimplecovReport.from_json(File.read(filename))

      data.each do |_service, report|
        report.coverage.each do |name, info|
          coverage = [] of Hits?
          branches = [] of Hits

          case info
          when Coverage
            coverage = info
          when ComplexCoverage
            coverage = info.lines
            info_branches = info.branches
            if info_branches
              prev_line = 0u64
              condition_number = 0u64
              info_branches.each do |branch, branch_info|
                line_number = branch.split(", ")[2].to_u64
                condition_number = 0u64 if line_number != prev_line
                prev_line = line_number
                branch_number = 0u64
                branch_info.each_value do |hits|
                  branch_number += 1
                  branches.push(line_number, condition_number, branch_number, hits)
                end
              ensure
                condition_number += 1
              end
            end
          end

          reports.push(
            file_report(
              name: name,
              coverage: coverage,
              branches: branches,
            )
          )
        end
      end

      reports
    end
  end
end
