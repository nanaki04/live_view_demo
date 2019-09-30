base_path = "assets/static/images"

{:ok, folders} = File.ls(base_path)

files = Enum.sort(folders, fn
          "title", _ -> true
          _, "title" -> false
          _, _ -> true
        end)
        |> Enum.map(fn folder -> {folder, File.ls("#{base_path}/#{folder}")} end)
        |> Enum.flat_map(fn
          {folder, {:ok, files}} -> Enum.map(files, fn file -> "/images/#{folder}/#{file}" end)
          {_, {:error, _}} -> []
        end)
        |> Enum.filter(fn file -> Regex.match?(~r/\.png$/, file) end)
        |> Enum.map(fn file -> "\"#{file}\"" end)
        |> Enum.join(",\n  ")

File.write("lib/master_data/space_birds/manifest.json", "[\n  #{files}\n]")
