defmodule SpicySupervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_init_args) do
    children = [Spicybot]

    Supervisor.init(children, strategy: :one_for_one)
  end
end


defmodule Spicybot do
  @moduledoc """
  Documentation for Spicybot.
  """
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Cache.GuildCache
  alias Nostrum.Voice

  import Nostrum.Struct.Embed

  require Logger

  @nut_file_url "https://brandthill.com/files/nut.wav"
  @you_killed_a_child "https://www.youtube.com/watch?v=V6O-vBVCbg0"

  def start_link do
    sounds =
      :code.priv_dir(:spicybot)
      |> Path.join("sounds.yaml")
      |> YamlElixir.read_from_file!

    :ets.new(:soundbites, [:set, :protected, :named_table])

    Enum.each(sounds, fn sound ->
      :ets.insert(:soundbites, {Map.get(sound, "id"), sound})
    end)

    Consumer.start_link(__MODULE__)
  end

  def get_voice_channel_of_msg(msg) do
    msg.guild_id
    |> GuildCache.get!()
    |> Map.get(:voice_states)
    |> Enum.find(%{}, fn v -> v.user_id == msg.author.id end)
    |> Map.get(:channel_id)
  end

  def do_not_ready_msg(msg) do
    Api.create_message(msg.channel_id, "I need to be in a voice channel for that")
  end

  def available_soundbites_embed() do
    sounds = :ets.match_object(:soundbites, {:"$0", :"$1"})
    fields =
      Enum.map(sounds, fn {_, %{"id" => id, "description" => desc}} -> %{name: id, value: desc} end)

    %Nostrum.Struct.Embed{
      title: "Spicy Sounds",
      fields: fields
    }
  end

  def play_soundbite(sound_id, msg) do
    case :ets.lookup(:soundbites, sound_id) do
      [] -> :noop
      [{id, %{"url" => url, "type" => type}}] ->
        if Voice.ready?(msg.guild_id) do
          Voice.play(msg.guild_id, url, String.to_atom(type))
        else
          do_not_ready_msg(msg)
        end
    end
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "summon!" ->
        case get_voice_channel_of_msg(msg) do
          nil ->
            Api.create_message(msg.channel_id, "Must be in a voice channel to summon")

          voice_channel_id ->
            Voice.join_channel(msg.guild_id, voice_channel_id)
        end

      "leave!" ->
        Voice.leave_channel(msg.guild_id)

      "play! help" ->
        Api.create_message(msg.channel_id, embed: available_soundbites_embed())

      "play!" <> sound_id ->
        play_soundbite(sound_id, msg)

      _ ->
        :noop
    end
  end

  def handle_event({:VOICE_SPEAKING_UPDATE, payload, _ws_state}) do
    Logger.debug("VOICE SPEAKING UPDATE #{inspect(payload)}")
  end

  def handle_event(_event) do
    :noop
  end
end
