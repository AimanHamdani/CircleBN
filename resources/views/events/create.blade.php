<x-app-layout>
    <x-slot name="header">
        <div class="flex items-center justify-between">
            <h2 class="font-semibold text-xl text-gray-800 dark:text-gray-100 leading-tight">
                Create New Event
            </h2>
            <a href="{{ route('events.index') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition">
                &larr; Back to Events
            </a>
        </div>
    </x-slot>

    <div class="py-8">
        <div class="max-w-3xl mx-auto sm:px-6 lg:px-8">
            <div class="bg-white dark:bg-gray-800 overflow-hidden shadow-sm sm:rounded-lg">
                <form method="POST" action="{{ route('events.store') }}" enctype="multipart/form-data" class="p-6 space-y-6">
                    @csrf

                    {{-- Title --}}
                    <div>
                        <x-input-label for="title" value="Event Title" />
                        <x-text-input id="title" name="title" type="text" class="mt-1 block w-full" :value="old('title')" required />
                        <x-input-error :messages="$errors->get('title')" class="mt-2" />
                    </div>

                    {{-- Category --}}
                    <div>
                        <x-input-label for="category" value="Category" />
                        <select id="category" name="category" class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 shadow-sm focus:ring-indigo-500 focus:border-indigo-500" required>
                            <option value="">Select a category</option>
                            <option value="marathon" @selected(old('category') === 'marathon')>Marathon</option>
                            <option value="hyrox" @selected(old('category') === 'hyrox')>Hyrox</option>
                            <option value="charity_run" @selected(old('category') === 'charity_run')>Charity Run</option>
                            <option value="community" @selected(old('category') === 'community')>Community</option>
                            <option value="other" @selected(old('category') === 'other')>Other</option>
                        </select>
                        <x-input-error :messages="$errors->get('category')" class="mt-2" />
                    </div>

                    {{-- Description --}}
                    <div>
                        <x-input-label for="description" value="Description" />
                        <textarea id="description" name="description" rows="5" class="mt-1 block w-full rounded-md border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 shadow-sm focus:ring-indigo-500 focus:border-indigo-500" required>{{ old('description') }}</textarea>
                        <x-input-error :messages="$errors->get('description')" class="mt-2" />
                    </div>

                    {{-- Location --}}
                    <div>
                        <x-input-label for="location" value="Location" />
                        <x-text-input id="location" name="location" type="text" class="mt-1 block w-full" :value="old('location')" required placeholder="e.g., Taman Mahkota Jubli Emas, Bandar Seri Begawan" />
                        <x-input-error :messages="$errors->get('location')" class="mt-2" />
                    </div>

                    {{-- Event Image --}}
                    <div>
                        <x-input-label for="image" value="Event Image (optional)" />
                        <input id="image" name="image" type="file" accept="image/*" class="mt-1 block w-full text-sm text-gray-500 dark:text-gray-400 file:mr-4 file:py-2 file:px-4 file:rounded-lg file:border-0 file:text-sm file:font-medium file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100 dark:file:bg-indigo-900/50 dark:file:text-indigo-300" />
                        <x-input-error :messages="$errors->get('image')" class="mt-2" />
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {{-- Registration Deadline --}}
                        <div>
                            <x-input-label for="registration_deadline" value="Registration Deadline" />
                            <x-text-input id="registration_deadline" name="registration_deadline" type="date" class="mt-1 block w-full" :value="old('registration_deadline')" required />
                            <x-input-error :messages="$errors->get('registration_deadline')" class="mt-2" />
                        </div>

                        {{-- Capacity --}}
                        <div>
                            <x-input-label for="capacity" value="Max Participants (leave empty for unlimited)" />
                            <x-text-input id="capacity" name="capacity" type="number" class="mt-1 block w-full" :value="old('capacity')" min="1" placeholder="Unlimited" />
                            <x-input-error :messages="$errors->get('capacity')" class="mt-2" />
                        </div>
                    </div>

                    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {{-- Starts At --}}
                        <div>
                            <x-input-label for="starts_at" value="Event Start Date & Time" />
                            <x-text-input id="starts_at" name="starts_at" type="datetime-local" class="mt-1 block w-full" :value="old('starts_at')" required />
                            <x-input-error :messages="$errors->get('starts_at')" class="mt-2" />
                        </div>

                        {{-- Ends At --}}
                        <div>
                            <x-input-label for="ends_at" value="Event End Date & Time" />
                            <x-text-input id="ends_at" name="ends_at" type="datetime-local" class="mt-1 block w-full" :value="old('ends_at')" required />
                            <x-input-error :messages="$errors->get('ends_at')" class="mt-2" />
                        </div>
                    </div>

                    {{-- Fee --}}
                    <div>
                        <x-input-label for="fee" value="Registration Fee (BND)" />
                        <x-text-input id="fee" name="fee" type="number" step="0.01" class="mt-1 block w-full" :value="old('fee', '0')" min="0" />
                        <p class="mt-1 text-sm text-gray-500 dark:text-gray-400">Set to 0 for free events.</p>
                        <x-input-error :messages="$errors->get('fee')" class="mt-2" />
                    </div>

                    <div class="flex items-center justify-end gap-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                        <a href="{{ route('events.index') }}" class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-200 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600 transition">
                            Cancel
                        </a>
                        <button type="submit" class="inline-flex items-center px-6 py-2 bg-indigo-600 border border-transparent rounded-lg text-sm font-medium text-white hover:bg-indigo-700 transition">
                            Create Event
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</x-app-layout>
