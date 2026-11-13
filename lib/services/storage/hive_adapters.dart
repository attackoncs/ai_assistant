import 'package:hive/hive.dart';

import '../../models/hive_models.dart';

// ─── ChatMessageBox (typeId: 0) ──────────────────────────────────────

class ChatMessageBoxAdapter extends TypeAdapter<ChatMessageBox> {
  @override
  final int typeId = 0;

  @override
  ChatMessageBox read(BinaryReader reader) {
    return ChatMessageBox(
      id: reader.readString(),
      conversationId: reader.readString(),
      role: reader.readString(),
      content: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessageBox obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.conversationId);
    writer.writeString(obj.role);
    writer.writeString(obj.content);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

// ─── ConversationBox (typeId: 1) ─────────────────────────────────────

class ConversationBoxAdapter extends TypeAdapter<ConversationBox> {
  @override
  final int typeId = 1;

  @override
  ConversationBox read(BinaryReader reader) {
    final hasPersonaId = reader.readBool();
    final hasLastMsg = reader.readBool();
    return ConversationBox(
      id: reader.readString(),
      title: reader.readString(),
      personaId: hasPersonaId ? reader.readString() : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      lastMessagePreview: hasLastMsg ? reader.readString() : null,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationBox obj) {
    writer.writeBool(obj.personaId != null);
    writer.writeBool(obj.lastMessagePreview != null);
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    if (obj.personaId != null) writer.writeString(obj.personaId!);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
    if (obj.lastMessagePreview != null) writer.writeString(obj.lastMessagePreview!);
  }
}

// ─── PersonaBox (typeId: 2) ──────────────────────────────────────────

class PersonaBoxAdapter extends TypeAdapter<PersonaBox> {
  @override
  final int typeId = 2;

  @override
  PersonaBox read(BinaryReader reader) {
    final hasEmoji = reader.readBool();
    return PersonaBox(
      id: reader.readString(),
      name: reader.readString(),
      description: reader.readString(),
      systemPrompt: reader.readString(),
      emoji: hasEmoji ? reader.readString() : null,
      category: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, PersonaBox obj) {
    writer.writeBool(obj.emoji != null);
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.description);
    writer.writeString(obj.systemPrompt);
    if (obj.emoji != null) writer.writeString(obj.emoji!);
    writer.writeString(obj.category);
  }
}

// ─── FavoriteBox (typeId: 3) ─────────────────────────────────────────

class FavoriteBoxAdapter extends TypeAdapter<FavoriteBox> {
  @override
  final int typeId = 3;

  @override
  FavoriteBox read(BinaryReader reader) {
    return FavoriteBox(
      id: reader.readString(),
      content: reader.readString(),
      source: reader.readString(),
      scene: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteBox obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.content);
    writer.writeString(obj.source);
    writer.writeString(obj.scene);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}
